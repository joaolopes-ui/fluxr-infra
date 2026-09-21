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

# Sem ingress inline aqui de propósito — o módulo containers adiciona a
# regra de entrada (só das tasks do ECS, via aws_security_group_rule
# separado) depois que esse security group existe. Antes disso havia uma
# regra provisória liberando a VPC inteira; removida agora que o acesso
# real (ECS) já está definido.
resource "aws_security_group" "db" {
  name        = "${var.project}-db"
  description = "Acesso ao Postgres do Fluxr"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-db-sg" }
}

# Senha do master gerenciada pela própria AWS (Secrets Manager) — nunca
# aparece em texto puro no código, no state ou nos logs do Terraform.
#
# storage_encrypted usa a chave default da AWS (alias/aws/rds) — o erro
# original (KMSKeyNotAccessibleFault) era só falta da permissão kms:* na
# policy do GitHub Actions (já corrigido no bootstrap), não ausência de
# chave. Uma chave KMS própria chegou a entrar aqui e foi revertida: o
# banco já foi criado com a chave default, e trocar a chave de um RDS
# existente exige destruir e recriar a instância — sem necessidade real.
resource "aws_db_instance" "main" {
  identifier     = "${var.project}-db"
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

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
