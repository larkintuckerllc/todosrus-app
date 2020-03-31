data "aws_acm_certificate" "this" {
  domain  = "legacy.todosrus.com"
}

data "aws_subnet_ids" "public" {
  tags = {
    Tier = "Public"
  }
  vpc_id = var.vpc_id
}

data "aws_subnet_ids" "private" {
  tags = {
    Tier = "Private"
  }
  vpc_id = var.vpc_id
}

data "aws_route53_zone" "this" {
  name = "todosrus.com."
}

data "aws_iam_policy" "amazon_ssm_managed_instance_core" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy" "cloud_watch_agent_server_policy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_security_group" "lb" {
  name   = "Legacy LB"
  vpc_id = var.vpc_id
}

resource "aws_security_group" "web" {
  name   = "Legacy Web"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "lb_ingress" {
  cidr_blocks = ["0.0.0.0/0"]
  from_port   = 443
  protocol    = "tcp"
  security_group_id = aws_security_group.lb.id
  to_port     = 443
  type        = "ingress"
}

resource "aws_security_group_rule" "lb_egress" {
  from_port   = 80
  protocol    = "tcp"
  security_group_id = aws_security_group.lb.id
  source_security_group_id = aws_security_group.web.id
  to_port     = 80
  type        = "egress"
}

resource "aws_security_group_rule" "web_egress" {
  cidr_blocks = ["0.0.0.0/0"]
  from_port   = 0
  protocol    = "-1"
  security_group_id = aws_security_group.web.id
  to_port     = 0
  type        = "egress"
}

resource "aws_security_group_rule" "web_lb" {
  type        = "ingress"
  from_port   = 80
  protocol    = "tcp"
  to_port     = 80
  security_group_id = aws_security_group.web.id
  source_security_group_id = aws_security_group.lb.id
}

resource "aws_security_group_rule" "web_bastion" {
  type        = "ingress"
  from_port   = 22
  protocol    = "tcp"
  to_port     = 22
  security_group_id = aws_security_group.web.id
  source_security_group_id = var.bastion_security_group_id
}

resource "aws_lb" "this" {
  internal           = false
  load_balancer_type = "application"
  name               = "Legacy"
  security_groups    = [aws_security_group.lb.id]
  subnets            = data.aws_subnet_ids.public.ids
}

resource "aws_lb_target_group" "this" {
  health_check {
    path = "/" 
  }
  name        = "Legacy"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
}

resource "aws_lb_listener" "this" {
  certificate_arn    = data.aws_acm_certificate.this.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
  load_balancer_arn  = aws_lb.this.arn
  port               = "443"
  protocol           = "HTTPS"
  ssl_policy         = "ELBSecurityPolicy-2016-08"
}

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.id
  name    = "legacy.todosrus.com"
  type    = "A"
  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = false
  }
}

resource "aws_iam_role" "legacy_ec2" {
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  name               = "LegacyEC2"
}

resource "aws_iam_instance_profile" "legacy_ec2" {
  name = "LegacyEC2"
  role = aws_iam_role.legacy_ec2.name
}

resource "aws_iam_role_policy_attachment" "legacy_ec2_amazon_ssm_managed_instance_core" {
  policy_arn = data.aws_iam_policy.amazon_ssm_managed_instance_core.arn
  role       = aws_iam_role.legacy_ec2.name
}

resource "aws_iam_role_policy_attachment" "legacy_ec2_cloud_watch_agent_server_policy" {
  policy_arn = data.aws_iam_policy.cloud_watch_agent_server_policy.arn
  role       = aws_iam_role.legacy_ec2.name
}

resource "aws_iam_role_policy" "legacy_ec2_s3_read_system_manager_run_command_ansible" {
    name   = "S3ReadSystemsManagerRunCommandAnsible"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::systems-manager-run-command-ansible/*",
                "arn:aws:s3:::systems-manager-run-command-ansible"
            ]
        }
    ]
}
EOF
    role   = aws_iam_role.legacy_ec2.id
}

resource "aws_iam_role_policy" "legacy_ec2_s3_write_legacy_upgrade_output" {
    name   = "S3WriteLegacyUpgradeOutput"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::legacy-upgrade-output/*"
        }
    ]
}
EOF
    role   = aws_iam_role.legacy_ec2.id
}

resource "aws_launch_template" "this" {
  iam_instance_profile {
    name = aws_iam_instance_profile.legacy_ec2.name
  }
  image_id               = var.legacy_image_id
  instance_type          = "t3.micro"
  key_name               = var.legacy_key_name
  name                   = "Legacy"
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Legacy"
    }
  }
  vpc_security_group_ids = [aws_security_group.web.id]
}

resource "aws_autoscaling_group" "this" {
  desired_capacity    = 1 
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
  max_size            = 1
  min_size            = 1
  name_prefix         = "Legacy-${aws_launch_template.this.latest_version}-"
  target_group_arns   = [aws_lb_target_group.this.arn]
  vpc_zone_identifier = data.aws_subnet_ids.private.ids
}
