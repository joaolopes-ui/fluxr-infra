variable "project" {
  type    = string
  default = "fluxr"
}

variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

variable "tf_state_bucket" {
  description = "Bucket de state do Terraform — precisa bater com o do bootstrap"
  type        = string
  default     = "fluxr-terraform-state"
}

variable "vpc_cidr" {
  description = "Precisa bater com o CIDR usado no módulo network"
  type        = string
  default     = "10.20.0.0/16"
}

variable "postgres_version" {
  description = "Versão major do Postgres — a AWS escolhe a minor mais recente disponível"
  type        = string
  default     = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_name" {
  type    = string
  default = "fluxr"
}

variable "master_username" {
  type    = string
  default = "fluxr_admin"
}

variable "backup_retention_days" {
  description = "Contas AWS no Free Tier têm um teto baixo aqui (confirmado via erro real: FreeTierRestrictionError pedindo 7 dias) — aumentar quando a conta sair do Free Tier."
  type        = number
  default     = 1
}
