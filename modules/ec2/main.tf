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

resource "aws_launch_template" "this" {
  image_id = var.legacy_image_id
  instance_type = "t3.micro"
  key_name = var.legacy_key_name
  name     = "Legacy"
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
