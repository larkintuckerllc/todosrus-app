data "aws_acm_certificate" "this" {
  domain  = "api.todosrus.com"
}

data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id
  tags = {
    Tier = "Public"
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id
  tags = {
    Tier = "Private"
  }
}

data "aws_route53_zone" "this" {
  name = "todosrus.com."
}

data "aws_iam_policy" "amazon_ecs_task_execution_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_ecr_repository" "this" {
  name = "todosrus"
}

# CHICKEN AND EGG SITUATION; REMOVE IF FIRST RUN
data "aws_ecs_cluster" "this" {
  cluster_name = "todosrus"
}

# CHICKEN AND EGG SITUATION; REMOVE IF FIRST RUN
data "aws_ecs_service" "this" {
  service_name = "todosrus"
  cluster_arn  = data.aws_ecs_cluster.this.arn
}

resource "aws_iam_role" "todos_r_us_ecs_execution" {
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  name               = "TodosRUsECSExecution"
}

resource "aws_iam_role_policy_attachment" "todosrus_ecs_amazon_ecs_task_execution_policy" {
  policy_arn = data.aws_iam_policy.amazon_ecs_task_execution_policy.arn
  role       = aws_iam_role.todos_r_us_ecs_execution.name
}

resource "aws_iam_role" "todos_r_us_ecs_custom" {
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  name               = "TodosRUsECSCustom"
}

resource "aws_iam_role_policy" "todos_r_us_ecs_custom_sns_subscribe_todos_create" {
    name   = "SNSSubscribeTodosCreate"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "sns:Subscribe",
            "Resource": "${var.todos_create_arn}"
        }
    ]
}
EOF
    role   = aws_iam_role.todos_r_us_ecs_custom.id
}

resource "aws_security_group" "lb" {
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "web" {
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "lb_ingress" {
  type        = "ingress"
  cidr_blocks = ["0.0.0.0/0"]
  from_port   = 443
  protocol    = "tcp"
  to_port     = 443
  security_group_id = aws_security_group.lb.id
}

resource "aws_security_group_rule" "lb_egress" {
  type        = "egress"
  source_security_group_id = aws_security_group.web.id
  from_port   = 80
  protocol    = "tcp"
  to_port     = 80
  security_group_id = aws_security_group.lb.id
}

resource "aws_security_group_rule" "web_egress" {
  type        = "egress"
  cidr_blocks = ["0.0.0.0/0"]
  from_port   = 0
  protocol    = "-1"
  to_port     = 0
  security_group_id = aws_security_group.web.id
}

resource "aws_security_group_rule" "web_lb" {
  type        = "ingress"
  source_security_group_id = aws_security_group.lb.id
  from_port   = 80
  protocol    = "tcp"
  to_port     = 80
  security_group_id = aws_security_group.web.id
}

resource "aws_lb" "this" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = data.aws_subnet_ids.public.ids
}

resource "aws_lb_target_group" "this" {
  health_check {
    path = "/hc" 
  }
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
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
  name    = "api.todosrus.com"
  type    = "A"
  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = false
  }
}

resource "aws_ecs_cluster" "this" {
  name = "todosrus"
}

resource "aws_ecs_task_definition" "this" {
    container_definitions    = <<EOF
[
  {
    "cpu": 256,
    "environment": [
      {
        "name": "APP_JWKS",
        "value": "${var.jwks}"
      },
      {
        "name": "APP_REGION",
        "value": "${var.aws_region_id}"
      },
      {
        "name": "APP_IDENTITY_POOL_ID",
        "value": "${var.identity_pool_id}"
      },
      {
        "name": "APP_ACCOUNT_ID",
        "value": "${var.aws_caller_identity_account_id}"
      },
      {
        "name": "APP_ISSUER",
        "value": "${var.issuer}"
      },
      {
        "name": "APP_IDENTITY_PROVIDER_NAME",
        "value": "${var.identity_provider_name}"
      },
      {
        "name": "APP_AUDIENCE",
        "value": "${var.audience}"
      },
      {
        "name": "APP_TOPIC_ARN",
        "value": "${var.todos_create_arn}"
      }
    ],
    "essential": true,
    "image": "${data.aws_ecr_repository.this.repository_url}",
    "memory": 512,
    "mountPoints": [],
    "name": "todosrus",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80,
        "protocol": "tcp" 
      }
    ],
    "volumesFrom": []
  }    
]
EOF
    cpu                      = 256
    execution_role_arn       = aws_iam_role.todos_r_us_ecs_execution.arn
    family                   = "todosrus"
    memory                   = 512
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    task_role_arn            = aws_iam_role.todos_r_us_ecs_custom.arn
}

resource "aws_ecs_service" "this" {
    cluster               = aws_ecs_cluster.this.id
    depends_on            = [aws_lb_listener.this]
  	desired_count         = 1
    launch_type           = "FARGATE"
    load_balancer {
      target_group_arn = aws_lb_target_group.this.arn
      container_name   = "todosrus"
      container_port   = 80 
    }
    name                  = "todosrus"
    network_configuration {
      security_groups     = [aws_security_group.web.id]
      subnets             = data.aws_subnet_ids.private.ids
    }
    task_definition       = var.task_change_flag ? aws_ecs_task_definition.this.arn : data.aws_ecs_service.this.task_definition
}