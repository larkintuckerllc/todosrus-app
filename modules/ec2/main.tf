data "aws_acm_certificate" "this" {
  domain  = "legacy.todosrus.com"
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
