output "deploy_role_arn" {
  description = "Cole isso no secret AWS_DEPLOY_ROLE_ARN do repositório no GitHub"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "terraform_state_bucket" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "terraform_lock_table" {
  value = aws_dynamodb_table.terraform_lock.name
}
