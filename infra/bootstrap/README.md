# Bootstrap — rodar UMA VEZ, você mesmo, localmente

Este módulo cria só o mínimo pra tudo o mais poder ser automatizado depois
sem que eu (Claude) precise ver nenhuma credencial da sua conta AWS:

- Bucket S3 + tabela DynamoDB pra guardar o state do Terraform dos próximos
  módulos (rede, banco, containers).
- O provedor OIDC que faz a AWS confiar no GitHub Actions.
- Uma IAM role que o GitHub Actions do repositório de infra pode assumir
  (sem chave de acesso estática nenhuma), com permissão só pro necessário na
  Fase 0 (rede, RDS, ECS/ECR, S3, Secrets Manager, logs).

## Pré-requisitos

- Terraform instalado (`brew install terraform` ou https://developer.hashicorp.com/terraform/install)
- AWS CLI configurado com um usuário/perfil SEU (`aws configure`), com
  permissão pra criar IAM roles, o provedor OIDC, bucket S3 e tabela
  DynamoDB. Pode ser um usuário administrador da conta, já que isso roda
  uma vez só, na sua máquina, e essa credencial nunca sai daqui.

## Passo a passo

```bash
cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars
# edite terraform.tfvars se o nome do repo de infra for diferente de "fluxr-infra"

terraform init
terraform plan     # confira o que vai ser criado antes de aplicar
terraform apply
```

Ao final, `terraform output` mostra `deploy_role_arn`, `terraform_state_bucket`
e `terraform_lock_table`. Guarde esses três valores:

1. `deploy_role_arn` → cadastre como secret `AWS_DEPLOY_ROLE_ARN` no
   repositório do GitHub (Settings → Secrets and variables → Actions).
2. `terraform_state_bucket` e `terraform_lock_table` → vão no bloco
   `backend "s3"` dos próximos módulos de infra (eu já deixo isso pronto
   quando escrever o módulo de rede/banco/containers).

Depois disso, **nenhum outro apply precisa ser feito manualmente** — o
GitHub Actions passa a aplicar tudo sozinho, autenticado via OIDC, sem
nenhuma chave de acesso guardada em lugar nenhum.
