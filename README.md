# fluxr-infra

> **Desativado.** O Fluxr ficou no Supabase + Vercel e esta infraestrutura AWS
> não vai ser usada. O apply automático foi removido; o workflow
> **Destruir infraestrutura AWS** apaga ECS, RDS e VPC/NAT. Depois dele, o
> bootstrap sai pelo CloudShell — ver "Desmontagem" no fim deste arquivo.

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

## Desmontagem

1. GitHub → Actions → **Destruir infraestrutura AWS** → Run workflow →
   digite `DESTRUIR`. Roda containers → database → network (o RDS demora
   ~10 min para apagar). Sem snapshot final: o banco nunca teve dados.
2. Depois que os 4 jobs ficarem verdes, apague o bootstrap pelo
   **CloudShell** do console AWS (região São Paulo, sa-east-1), com um
   usuário administrador:

```bash
# role do GitHub Actions (política inline primeiro)
aws iam delete-role-policy --role-name fluxr-github-actions-deploy --policy-name fluxr-phase0-permissions
aws iam delete-role --role-name fluxr-github-actions-deploy

# provedor OIDC do GitHub
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn \
  arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com

# tabela de lock e bucket de state (versionado: apaga todas as versões)
aws dynamodb delete-table --table-name fluxr-terraform-lock --region sa-east-1
python3 -c "import boto3; b=boto3.resource('s3').Bucket('fluxr-terraform-state'); b.object_versions.delete(); b.delete(); print('bucket apagado')"
```

3. No GitHub, remova o secret `AWS_DEPLOY_ROLE_ARN` deste repositório e, se
   quiser, arquive o repositório.
