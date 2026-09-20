terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Este módulo é o único que roda com state LOCAL (na sua máquina), porque
  # ele mesmo cria o bucket/tabela que os outros módulos vão usar como
  # backend remoto. Rode uma vez, guarde o .tfstate gerado em local seguro
  # (ou migre pra um backend depois) — os módulos seguintes (VPC/RDS/ECS)
  # já nascem configurados pra usar o backend S3 criado aqui.
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────────────────────────────────
# Backend remoto de state — usado pelos módulos de infra "de verdade"
# (rede, banco, containers), não por este bootstrap.
# ─────────────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project}-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${var.project}-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ─────────────────────────────────────────────────────────────────────────
# Provedor OIDC de confiança do GitHub Actions. O thumbprint é obtido AO VIVO
# via data source (não hardcoded) — evita fixar um hash de certificado que
# pode ficar desatualizado se o GitHub rotacionar o certificado no futuro.
# ─────────────────────────────────────────────────────────────────────────
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

# ─────────────────────────────────────────────────────────────────────────
# Role que o GitHub Actions assume via OIDC — sem nenhuma chave de acesso
# estática guardada em lugar nenhum. Restrito ao repo informado em
# var.github_repo; qualquer branch/PR desse repo pode assumir por enquanto
# (dá pra apertar depois, restringindo só a "ref:refs/heads/main").
# ─────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect = "Allow"
    # sts:TagSession é obrigatório aqui porque o aws-actions/configure-aws-credentials
    # v4 marca a sessão assumida com tags automáticas (repo, actor, ref, sha, ...) —
    # sem essa permissão a AWS rejeita a chamada inteira com "Not authorized to
    # perform sts:AssumeRoleWithWebIdentity" (mensagem enganosa: o que falta é
    # TagSession, não AssumeRoleWithWebIdentity em si).
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Duas formas porque o GitHub pode emitir o claim "sub" com ou sem os IDs
    # numéricos imutáveis (ex.: "repo:org@123/repo@456:ref:..." em vez do
    # clássico "repo:org/repo:ref:..."), dependendo da configuração da conta
    # — confirmado via CloudTrail (campo Username do evento
    # AssumeRoleWithWebIdentity negado) que esta conta usa o formato com ID.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo}:*",
        "repo:${var.github_org}@*/${var.github_repo}@*:*",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "${var.project}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# Permissões da Fase 0: rede, banco (RDS), containers (ECS/ECR), storage (S3),
# segredos e logs. Nada de "iam:*" nem AdministratorAccess — o suficiente pra
# montar VPC + RDS + ECS Fargate + S3 + Secrets Manager. Pode (e deve) ser
# apertado depois que a Fase 0 estabilizar.
data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid    = "TerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:ListBucket",
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem",
    ]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
      aws_dynamodb_table.terraform_lock.arn,
    ]
  }

  statement {
    sid    = "Fase0Infra"
    effect = "Allow"
    actions = [
      "ec2:*", "rds:*", "ecs:*", "ecr:*", "elasticloadbalancing:*",
      "s3:*", "secretsmanager:*", "logs:*", "application-autoscaling:*",
      "servicediscovery:*",
    ]
    resources = ["*"]
  }

  # IAM só pra criar/gerenciar roles DESTE projeto (prefixo "${var.project}-"),
  # nunca acesso geral a IAM — é o mínimo pra criar as task roles do ECS.
  statement {
    sid    = "RolesDoProjeto"
    effect = "Allow"
    actions = [
      "iam:PassRole", "iam:CreateRole", "iam:DeleteRole", "iam:AttachRolePolicy",
      "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:GetRole", "iam:TagRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
    ]
    resources = ["arn:aws:iam::*:role/${var.project}-*"]
  }
}

resource "aws_iam_role_policy" "github_actions_permissions" {
  name   = "${var.project}-phase0-permissions"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
