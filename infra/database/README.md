# database

RDS Postgres (managed, não é um container que a gente opera na unha), numa
subnet privada da VPC criada pelo módulo `network`. Sem IP público — só
acessível de dentro da VPC.

- Instância `db.t4g.micro`, 20GB gp3 (auto-scaling até 100GB), criptografado.
- Senha do master gerenciada pela AWS no Secrets Manager (`manage_master_user_password = true`)
  — nunca fica em texto puro em lugar nenhum; o ARN do secret sai como output
  (`db_master_user_secret_arn`) pra quem precisar ler (ex.: o módulo
  `containers`, quando existir, vai usar isso pra configurar o PostgREST/GoTrue).
- Backup automático com retenção de 7 dias.
- `skip_final_snapshot = true` e `deletion_protection = false` — ainda é
  ambiente de teste/validação, não produção com dado real. Reconsiderar
  antes de qualquer corte de tráfego de verdade do Fluxr pra cá.

## Próximo módulo

`containers` — ECS Fargate rodando PostgREST/GoTrue/Storage API, apontando
pra este banco. Vai precisar de uma regra de security group liberando 5432
só das tasks do ECS (hoje a regra aqui libera a VPC inteira, temporário).
