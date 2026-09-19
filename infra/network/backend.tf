# Backend parcial de propósito — o bucket/tabela/região vêm do
# -backend-config passado pelo workflow do GitHub Actions (ver
# .github/workflows/terraform.yml), pra não hardcodar esses valores em cada
# módulo. Pra rodar localmente (ex.: só pra inspecionar), use:
#
#   terraform init \
#     -backend-config="bucket=fluxr-terraform-state" \
#     -backend-config="key=network/terraform.tfstate" \
#     -backend-config="region=sa-east-1" \
#     -backend-config="dynamodb_table=fluxr-terraform-lock"
terraform {
  backend "s3" {}
}
