provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
}

module "ecs" {
  source = "./modules/ecs"
  certificate_arn = var.certificate_arn
  execution_role_arn = var.execution_role_arn
  image = var.image
  task_role_arn = var.task_role_arn
}

module "lambda_function_create_publish" {
  source = "./modules/lambda-todos-create-publish"
  lambda_basic_execution_arn = aws_iam_policy.lambda_basic_execution.arn
  todos_create_arn = aws_sns_topic.todos_create.arn
  todos = aws_dynamodb_table.todos
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
