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

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.tf_state_bucket
    key    = "network/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket = var.tf_state_bucket
    key    = "database/terraform.tfstate"
    region = var.aws_region
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = { Name = "${var.project}-cluster" }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project}"
  retention_in_days = 14
  tags              = { Name = "${var.project}-ecs-logs" }
}

# Role que toda task Fargate usa pra puxar a imagem do registry e escrever
# log no CloudWatch — não é a role da aplicação em si (essa vem por task,
# quando os serviços de verdade forem definidos no próximo módulo).
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project}-ecs-execution" }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Security group das tasks do ECS — qualquer serviço que rodar aqui (ainda
# nenhum, isso vem no próximo módulo) sai por trás dele.
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project}-ecs-tasks"
  description = "Tasks do ECS (PostgREST/GoTrue/Storage API, quando existirem)"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-ecs-tasks-sg" }
}

# Aperta o acesso ao banco: só as tasks do ECS, não a VPC inteira (a regra
# ampla que o módulo database criou como provisório já foi removida de lá).
resource "aws_security_group_rule" "db_from_ecs_tasks" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.database.outputs.db_security_group_id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description               = "Postgres a partir das tasks do ECS"
}
