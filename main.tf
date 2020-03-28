terraform {
  backend "remote" {
    organization = "todosrus"
    workspaces {
      name = "todosrus-app"
    }
  }
}

data "terraform_remote_state" "net" {
  backend = "remote"
  config = {
    organization = "todosrus"
    workspaces = {
      name = "todosrus-net"
    }
  }
}

provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
}

data "aws_region" "this" {}

data "aws_caller_identity" "this" {}

module "ecs" {
  source = "./modules/ecs"
  audience = var.audience
  aws_region_id = data.aws_region.this.id
  aws_caller_identity_account_id = data.aws_caller_identity.this.account_id
  identity_pool_id = var.identity_pool_id
  identity_provider_name = var.identity_provider_name
  issuer = var.issuer
  jwks = var.jwks
  task_change_flag = var.task_change_flag
  todos_create_arn = aws_sns_topic.todos_create.arn
  vpc_id = data.terraform_remote_state.net.outputs.vpc_id
}

module "lambda_function_create_publish" {
  source = "./modules/lambda-todos-create-publish"
  aws_region_id = data.aws_region.this.id
  aws_caller_identity_account_id = data.aws_caller_identity.this.account_id
  lambda_basic_execution_arn = aws_iam_policy.lambda_basic_execution.arn
  todos_create_arn = aws_sns_topic.todos_create.arn
  todos = aws_dynamodb_table.todos
}

module "ec2" {
  source = "./modules/ec2"
  vpc_id = data.terraform_remote_state.net.outputs.vpc_id
}

resource "aws_dynamodb_table" "todos" {
  attribute {
    name = "IdentityId"
    type = "S"
  }
  attribute {
    name = "Id"
    type = "S"
  }
  hash_key         = "IdentityId"
  name             = "Todos"
  range_key        = "Id"
  read_capacity    = 1 
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
  write_capacity   = 1
}

resource "aws_dynamodb_table" "subscriptions" {
  attribute {
    name = "IdentityId"
    type = "S"
  }
  hash_key       = "IdentityId"
  name           = "Subscriptions"
  read_capacity  = 1 
  write_capacity = 1
}

resource "aws_sns_topic" "todos_create" {
  name = "TodosCreate"
}

resource "aws_iam_policy" "lambda_basic_execution" {
  name        = "LambdaBasicExecution"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}
