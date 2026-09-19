variable "project" {
  description = "Prefixo usado no nome dos recursos (bucket, tabela, role)"
  type        = string
  default     = "fluxr"
}

variable "aws_region" {
  description = "Região AWS onde tudo vai rodar"
  type        = string
  default     = "sa-east-1"
}

variable "github_org" {
  description = "Organização/usuário dono do repositório de infra no GitHub"
  type        = string
}

variable "github_repo" {
  description = "Nome do repositório de infra no GitHub (sem o org/usuário)"
  type        = string
}
