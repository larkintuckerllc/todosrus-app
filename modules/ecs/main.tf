data "aws_acm_certificate" "this" {
  domain   = "api.todosrus.com"
}

data "aws_vpc" "this" {
  tags = {
    Name = "development"
  }
}

data "aws_subnet_ids" "this" {
  vpc_id = data.aws_vpc.this.id
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

resource "aws_security_group" "this" {
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80 
    protocol    = "tcp"
    to_port     = 80 
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443 
    protocol    = "tcp"
    to_port     = 443
  }
  vpc_id      = data.aws_vpc.this.id
}

resource "aws_lb" "this" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.this.id]
  subnets            = data.aws_subnet_ids.this.ids
}

resource "aws_lb_target_group" "this" {
  health_check {
    path = "/hc" 
  }
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.this.id
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
        "value": "{\"keys\":[{\"alg\":\"RS256\",\"e\":\"AQAB\",\"kid\":\"WDrEvr7DlJysick7MVtKUg7NNJF2bc0KAeX23wkDZHU=\",\"kty\":\"RSA\",\"n\":\"p_vbr2rg7CxvY9CeMpoJa4FXwB3UsW2pVOx2_Dz9xYslKxH7_Ylq8smGhg0vKbzhmyX3LQCgdKa8Fl49ufUO20Vwy0PwKCDp0_Yj6PCcJdE6bwc16TiB9CwRnP2Sr0zSJnT5Qtwn6b0juUh6wc-FVHmcyKHWYc-AHqpnTaZ4aVKlc77D1JbXInEBUcrudg5MZFwP20UzuYpdtgzokglwqZr87Z9rqc_whOzu9Lxh_tR6sYq3jIxG9gKKTDY5WmdvUUkTV5a1vINSzScIbFZ1i8uvg64yCuS-GOFeaMlcDDLFIbwhkOWGPuJKP38i7k_SU-wenQ_553Fb5hp2_eHb9Q\",\"use\":\"sig\"},{\"alg\":\"RS256\",\"e\":\"AQAB\",\"kid\":\"r6yNTuoRqAiQ/Oj6lJa9684WGzfsM+juu7x6E90u/i4=\",\"kty\":\"RSA\",\"n\":\"hHkn6ROe_-QiflYOh1WIbvQieaV2TN4ZXcIp_tdfCAMf_Vl0POkyI4jtmD59eLrWkgZZx8zewGij7UgwpisKxUCmbtZIbnEWLOREdR33kxlJiMNbiye8nXSYP2Ea4M1lIaRWcA60nzDScLqj_BBYaXve0e6g87GadyAIwqbfX-kqPHkGntduf3ol3FeJBri3bYcnTNFGMdvRx1lc5sYDd3VRVh5Ipu7LVvK9FIKZL9ZBPS2iOxGRT8vuNgdOaTxwZ_eXwQbcJWY0CHiAFMXQXrK3xGTuKtKODUOX-Uc5cJrOW4qAJpZK5YHUF1ZyCzMLsSl21QcUMovUmNjtUbgTSQ\",\"use\":\"sig\"}]}"
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
        "value": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_rIytU4eSc"
      },
      {
        "name": "APP_IDENTITY_PROVIDER_NAME",
        "value": "cognito-idp.us-east-1.amazonaws.com/us-east-1_rIytU4eSc"
      },
      {
        "name": "APP_AUDIENCE",
        "value": "3mvlgjo1u6idlujdatvk83698p"
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
  	desired_count         = 3
    launch_type           = "FARGATE"
    load_balancer {
      target_group_arn = aws_lb_target_group.this.arn
      container_name   = "todosrus"
      container_port   = 80 
    }
    name                  = "todosrus"
    network_configuration {
      assign_public_ip    = true
      security_groups     = [aws_security_group.this.id]
      subnets             = data.aws_subnet_ids.this.ids
    }
    task_definition       = aws_ecs_task_definition.this.arn
}
