terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Lê a VPC/subnets criadas pelo módulo network, sem duplicar esses valores
# aqui — o database depende do network, não o contrário.
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.tf_state_bucket
    key    = "network/terraform.tfstate"
    region = var.aws_region
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db"
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  tags       = { Name = "${var.project}-db-subnet-group" }
}

# Libera 5432 só de dentro da VPC por enquanto — quando o módulo containers
# existir (ECS rodando PostgREST/GoTrue), trocar essa regra por uma
# apontando só pro security group das tasks do ECS, mais restrita que a
# VPC inteira.
resource "aws_security_group" "db" {
  name        = "${var.project}-db"
  description = "Acesso ao Postgres do Fluxr"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description = "Postgres de dentro da VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-db-sg" }
}

# Chave própria em vez da default gerenciada pela AWS (alias/aws/rds) —
# essa alias só é criada automaticamente na primeira vez que é usada pelo
# CONSOLE da AWS, não via API/Terraform. Confirmado via erro real:
# KMSKeyNotAccessibleFault "[null]" ao tentar criar o RDS numa conta nova
# sem nenhuma chave default ainda provisionada.
resource "aws_kms_key" "rds" {
  description             = "Criptografia do RDS Postgres do Fluxr"
  deletion_window_in_days = 7
  tags                    = { Name = "${var.project}-rds-kms" }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# Senha do master gerenciada pela própria AWS (Secrets Manager) — nunca
# aparece em texto puro no código, no state ou nos logs do Terraform.
resource "aws_db_instance" "main" {
  identifier     = "${var.project}-db"
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name                     = var.db_name
  username                    = var.master_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  multi_az                = false
  backup_retention_period = var.backup_retention_days
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = { Name = "${var.project}-db" }
}
