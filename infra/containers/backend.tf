# Mesmo padrão dos outros módulos — bucket/key/região vêm do
# -backend-config passado pelo workflow do GitHub Actions.
terraform {
  backend "s3" {}
}
