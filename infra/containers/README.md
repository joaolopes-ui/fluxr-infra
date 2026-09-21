# containers

Fundação do ECS — ainda **sem nenhum serviço rodando**, de propósito
(mesmo padrão do `network` antes do `database`: primeiro a base, valida,
depois o que roda em cima).

- Cluster ECS Fargate vazio.
- Role de execução das tasks (permissão de puxar imagem + escrever log —
  não é a role da aplicação em si).
- Log group no CloudWatch.
- Security group das tasks do ECS.
- Aperta o acesso ao Postgres: a regra provisória que liberava a VPC
  inteira (criada no módulo `database`) foi removida de lá; agora só as
  tasks deste security group alcançam a porta 5432.

## Próximo módulo

Os serviços de verdade: task definitions + ECS services pro PostgREST,
GoTrue (auth) e Storage API do Supabase self-hosted, apontando pro RDS
deste ambiente, atrás de um Application Load Balancer. Precisa também de
um passo de bootstrap do schema (roles `anon`/`authenticated`/`service_role`/
`authenticator`) — como o RDS só é alcançável de dentro da VPC, isso roda
como uma task avulsa do ECS, não direto do GitHub Actions.
