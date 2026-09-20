# Mesmo padrão do módulo network — bucket/key/região vêm do -backend-config
# passado pelo workflow do GitHub Actions.
terraform {
  backend "s3" {}
}
