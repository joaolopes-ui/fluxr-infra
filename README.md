# fluxr-infra

Infraestrutura AWS do Fluxr — migração gradual (strangler fig) pra fora do
Base44/Supabase Cloud, módulo por módulo, com o Fluxr seguindo em produção
no Base44 durante todo o processo.

## Estrutura

- `infra/bootstrap/` — módulo aplicado manualmente, uma vez, localmente
  (nunca via CI). Cria o backend remoto de state (S3 + DynamoDB) e a role
  OIDC que o GitHub Actions usa pra aplicar tudo o mais, sem nenhuma chave
  de acesso estática guardada em lugar nenhum. Ver o README dentro da pasta.
- `infra/<próximos módulos>/` — rede (VPC), banco (RDS Postgres), containers
  (ECS Fargate rodando PostgREST/GoTrue/Storage API), aplicados via GitHub
  Actions a partir daqui em diante.

## Como tudo se conecta

1. `infra/bootstrap` é aplicado uma vez, manualmente, com uma credencial
   AWS pessoal — nunca reaplicado depois disso.
2. A saída dele (`deploy_role_arn`) vira o secret `AWS_DEPLOY_ROLE_ARN`
   deste repositório no GitHub (Settings → Secrets and variables → Actions).
3. Todo módulo seguinte é aplicado pelo GitHub Actions, autenticado via
   OIDC usando essa role — PR abre e faz `terraform plan`, merge em `main`
   faz `terraform apply`.
