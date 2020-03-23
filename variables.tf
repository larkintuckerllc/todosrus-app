# Terraform: todosrus-net
# Route 53: todosrus.com
# S3: todosrus.com
# CloudFront: todosrus.com
# CodeCommit: backend
# CodeBuild: backend
# CodePipeline: backend
# CodeCommit: frontend
# CodeBuild: frontend
# CodeBuild: frontend-postbuild
# CodePipeline: frontend
# Cogntio: User Pool: customers
# Cognito: Identity Pool: customers

variable "certificate_arn" { }
variable "execution_role_arn" { }
variable "image" { }
variable "task_role_arn" { }
