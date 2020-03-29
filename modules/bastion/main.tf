data "aws_acm_certificate" "this" {
  domain  = "legacy.todosrus.com"
}

data "aws_subnet_ids" "public" {
  tags = {
    Tier = "Public"
  }
  vpc_id = var.vpc_id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_security_group" "bastion" {
  name   = "Bastion"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "bastion_ingress" {
  cidr_blocks = ["0.0.0.0/0"]
  from_port   = 22
  protocol    = "tcp"
  security_group_id = aws_security_group.bastion.id
  to_port     = 22
  type        = "ingress"
}

resource "aws_security_group_rule" "bastion_egress" {
  cidr_blocks = ["0.0.0.0/0"]
  from_port   = 0
  protocol    = "-1"
  security_group_id = aws_security_group.bastion.id
  to_port     = 0
  type        = "egress"
}

resource "aws_instance" "this" {
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = "t2.micro"
  key_name                = var.legacy_key_name
  subnet_id               = tolist(data.aws_subnet_ids.public.ids)[0]
  vpc_security_group_ids = [aws_security_group.bastion.id]
  tags = {
    Name = "Bastion"
  }
}
