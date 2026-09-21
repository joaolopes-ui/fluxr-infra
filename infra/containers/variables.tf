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
