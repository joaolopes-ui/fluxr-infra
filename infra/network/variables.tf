variable "project" {
  description = "Prefixo usado no nome dos recursos"
  type        = string
  default     = "fluxr"
}

variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC — /16 dá espaço pra 16 subnets /20 se precisar crescer"
  type        = string
  default     = "10.20.0.0/16"
}
