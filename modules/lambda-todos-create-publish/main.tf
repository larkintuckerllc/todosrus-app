resource "aws_iam_role" "lambda_todos_create_publish" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  name               = "TodosCreatePublishLambda"
}

resource "aws_iam_role_policy_attachment" "lambda_todos_create_publish_lambda_basic_execution" {
  policy_arn = var.lambda_basic_execution_arn
  role       = aws_iam_role.lambda_todos_create_publish.name
}

resource "aws_iam_role_policy" "lamda_todos_create_publish_dynamodb_todos_read_stream" {
    name   = "DynamoDBTodosReadStream"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetShardIterator",
                "dynamodb:DescribeStream",
                "dynamodb:GetRecords"
            ],
            "Resource": "arn:aws:dynamodb:${var.aws_region_id}:${var.aws_caller_identity_account_id}:table/${var.todos.name}/stream/*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "dynamodb:ListStreams",
            "Resource": "*"
        }
    ]
}
EOF
    role   = aws_iam_role.lambda_todos_create_publish.id
}

resource "aws_iam_role_policy" "lamda_todos_create_publish_sns_todos_publish" {
    name   = "SNSTodosPublish"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "sns:Publish",
            "Resource": "${var.todos_create_arn}"
        }
    ]
}
EOF
    role   = aws_iam_role.lambda_todos_create_publish.id
}

resource "aws_lambda_function" "todos_create_publish" {
  environment {
    variables = {
      APP_TOPIC_ARN = var.todos_create_arn
    }
  }
  filename         = "./modules/lambda-todos-create-publish/lambda_function_python.zip"
  function_name    = "TodosCreatePublish"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.lambda_todos_create_publish.arn
  runtime          = "python3.8"
}

resource "aws_lambda_alias" "todos_create_publish_development" {
  function_name    = aws_lambda_function.todos_create_publish.arn
  function_version = "$LATEST"
  lifecycle {
    ignore_changes = [function_version]
  }
  name             = "development"
}

resource "aws_lambda_event_source_mapping" "todos_create_publish_event_dynamodb" {
  event_source_arn  = var.todos.stream_arn
  function_name     = aws_lambda_alias.todos_create_publish_development.arn
  starting_position = "LATEST"
}
