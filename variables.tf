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

# Cognito: Identity Pool: customers
variable "identity_pool_id" { }

# Cogntio: User Pool: customers
variable "audience" { }
variable "identity_provider_name" { }
variable "issuer" { }
variable "jwks" { }
