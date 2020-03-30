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

variable "audience" { } # Cognito: User Pool: customers
variable "bastion_security_group_id" { } # CloudFormation: Linux-bastion
variable "identity_pool_id" { } # Cognito: Identity Pool: customers
variable "identity_provider_name" { } # Cognito: User Pool: customers
variable "issuer" { } # Cognito: User Pool: customers
variable "jwks" { } # Cognito: User Pool: customers
variable "legacy_image_id" { } # Packer
variable "legacy_key_name" { } # Packer
variable "task_change_flag" {
  default = false
}
