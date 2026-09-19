# network

VPC com 2 subnets públicas + 2 privadas (2 zonas de disponibilidade em
sa-east-1), 1 Internet Gateway e 1 NAT Gateway. Base pros próximos módulos:
`database` (RDS Postgres, subnet privada) e `containers` (ECS Fargate rodando
PostgREST/GoTrue/Storage API, subnet privada, saindo pra internet via NAT).

Este é o primeiro módulo aplicado pelo GitHub Actions (via OIDC), não mais
manualmente — abrir um PR que mexe em `infra/network/` já dispara um
`terraform plan` comentado automaticamente no PR; merge em `main` aplica.
