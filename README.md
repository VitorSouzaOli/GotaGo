# GotaGo

App de hidratação em equipe: registre a água do dia, mantenha a sequência de metas
cumpridas, desbloqueie conquistas e dispute ligas com amigos.

| Pasta | Conteúdo |
|---|---|
| `src/` | API REST: Node.js, Fastify, TypeScript, Zod e JWT |
| `prisma/` | Esquema do banco (PostgreSQL), migrações e seed |
| `tests/` | Testes do backend (Vitest; não precisam de banco) |
| `mobile/` | App Flutter ([guia próprio](mobile/README.md)) |

## Como rodar o backend

Os comandos abaixo são executados na raiz do repositório (PowerShell, bash ou zsh).

### 1. Pré-requisitos

- [Node.js](https://nodejs.org) 22 ou mais novo
- PostgreSQL 16, **ou** Docker Desktop para rodá-lo em contêiner

### 2. Instale as dependências

```powershell
npm install
```

### 3. Crie o arquivo `.env`

```powershell
cp .env.example .env
```

Troque o `JWT_SECRET` por um valor gerado com:

```powershell
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

Se o arquivo `.env` já existe, não é preciso copiar de novo: compare com o exemplo e
acrescente o que faltar.

> Salve o `.env` em **UTF-8 sem BOM**. Com BOM, o Node não lê a primeira variável.

### 4. Suba o banco (escolha um)

**Opção A: Docker** (abra o Docker Desktop antes). O `DATABASE_URL` do exemplo já funciona.

```powershell
npm run db:up
```

**Opção B: PostgreSQL instalado no computador.** Crie o usuário e o banco no `psql`
(como administrador) e ajuste a senha no `DATABASE_URL`:

```sql
CREATE USER gotago WITH PASSWORD 'escolha-uma-senha' CREATEDB;
CREATE DATABASE gotago_db OWNER gotago;
```

As duas opções usam a porta 5432. Se você já tem um PostgreSQL instalado e quer usar o
Docker, defina `POSTGRES_PORT=5433` no `.env` e use `5433` no `DATABASE_URL`.

### 5. Crie as tabelas e os dados de teste

```powershell
npm run db:deploy
```

```powershell
npm run db:seed
```

O seed é opcional e cria o usuário `teste@gotago.dev` (senha `123456`) e a liga
`GOTA-TEST`. Use apenas em desenvolvimento.

### 6. Inicie a API

```powershell
npm run dev
```

Abra <http://localhost:3333/health>. A resposta esperada é
`{"status":"ok","service":"GotaGo API"}`.

## Como rodar o app

Precisa do [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.13.7 ou
mais novo). Com a API ligada, em **outro terminal**:

```powershell
cd mobile
```

```powershell
flutter pub get
```

Escolha onde rodar:

```powershell
flutter run -d chrome --dart-define=MOCK_API=false
```

```powershell
flutter run --dart-define=MOCK_API=false
```

O primeiro comando usa o navegador (não exige Android Studio). O segundo usa o
emulador Android aberto. Sem `--dart-define=MOCK_API=false`, o app abre em **modo
demo**, com dados falsos e sem chamar a API. Para celular físico, veja o
[guia do app](mobile/README.md#endereço-da-api).

## Comandos do backend

| Comando | O que faz |
|---|---|
| `npm run dev` | API com recarga automática |
| `npm test` | Testes |
| `npm run test:coverage` | Testes com relatório de cobertura |
| `npm run typecheck` | Checagem de tipos |
| `npm run build` e `npm start` | Compila para `dist/` e roda a versão compilada |
| `npm run db:migrate` | Cria uma migração depois de mudar o `schema.prisma` |
| `npm run db:deploy` | Aplica as migrações pendentes |
| `npm run db:seed` | Insere os dados de teste |

## Variáveis de ambiente

| Variável | Obrigatória | Para quê |
|---|---|---|
| `DATABASE_URL` | sim | Conexão com o PostgreSQL |
| `JWT_SECRET` | sim | Assina os tokens de sessão |
| `PORT` | não (3333) | Porta da API |
| `TZ` | não (fuso do sistema) | Define quando o dia começa. Em servidores, use `America/Sao_Paulo` |
| `CORS_ORIGIN` | não (todas) | Sites autorizados, separados por vírgula |
| `APP_URL` | não | Endereço público usado no link de recuperação de senha |
| `TRUST_PROXY` | não (`false`) | `true` se houver proxy reverso |
| `PRISMA_LOG_QUERIES` | não (`false`) | Mostra as consultas SQL |

## Rotas da API

Fora as marcadas como públicas, todas exigem `Authorization: Bearer <token>`.
Erros respondem `{ "error": "..." }`; dados inválidos incluem a lista `issues`.

| Rota | O que faz |
|---|---|
| `GET /health` | Pública. Estado da API |
| `POST /users` | Pública. Cadastro: `name`, `username`, `email`, `password`, `weightKg?`, `customDailyGoal?`, `avatarUrl?`. Devolve `token` e `user` |
| `POST /sessions` | Pública. Login: `login` (e-mail ou username) e `password` |
| `GET /users/me` | Perfil atual |
| `PATCH /users/:userId` | Altera `name`, `weight`, `dailyGoal` (mínimo 2000) |
| `PATCH /users/:userId/password` | `currentPassword`, `newPassword` |
| `DELETE /users/:userId` | Exclui a conta; ligas passam ao membro mais antigo |
| `POST /passwords/forgot` | Pública. `email`. Gera um link válido por 1 hora |
| `GET /passwords/reset` | Pública. Página para criar a nova senha |
| `POST /passwords/reset` | Pública. `token`, `password` |
| `POST /water-logs` | Registra `amount` (1 a 5.000 ml) |
| `PATCH /water-logs/:id` | Corrige `amount` ou `createdAt` (no mesmo dia) |
| `DELETE /water-logs/:id` | Exclui um registro |
| `GET /users/:userId/water-logs?days=30` | Registros dos últimos dias (até 90) |
| `GET /water-logs/today` | Resumo de hoje |
| `GET /water-logs/history?days=7` | Total por dia |
| `GET /users/:userId/achievements` | Conquistas |
| `POST /leagues` | Cria liga: `name`, `description?`, `endDate?` |
| `POST /leagues/join` | Entra com `code` |
| `GET /leagues` ou `GET /users/:userId/leagues` | Minhas ligas |
| `GET /leagues/code/:code` | Prévia antes de entrar |
| `GET /leagues/:id/leaderboard` | Ranking (só membros) |
| `PATCH /leagues/:id` | Renomeia (administrador) |
| `POST /leagues/:id/code` | Gera novo código (administrador) |
| `DELETE /leagues/:id/members/:userId` | Sai da liga ou remove um membro |

Há limite de tentativas por IP no cadastro, login, senhas e códigos de convite (429).

## Meta diária

- Calculada em [`calculate-water-goal.ts`](src/utils/calculate-water-goal.ts):
  35 ml por kg de peso, **nunca abaixo de 2000 ml**.
- A pessoa pode trocar a meta calculada por uma própria, sempre com no mínimo
  2000 ml (no cadastro e no `PATCH /users/:userId`).
- O app repete esse cálculo em `mobile/lib/core/utils/water_goal.dart`, para
  mostrar a estimativa enquanto a pessoa digita. Mudou um, mude o outro.

## Regras de sequência

- A sequência é calculada a partir dos registros: dias seguidos em que o total atingiu a
  meta. O dia de hoje, enquanto não termina, não a quebra.
- Cada registro guarda a meta da época. Mudar a meta vale de hoje em diante.
- Editar ou excluir um registro recalcula a sequência. Conquistas já desbloqueadas permanecem.

## Antes de publicar em produção

- **E-mail:** não há provedor configurado. Implemente o envio em
  [`src/lib/mailer.ts`](src/lib/mailer.ts); com `NODE_ENV=production` o link não é exibido.
- **Sessões:** trocar a senha não invalida tokens já emitidos (expiram em 7 dias).
- **Limite de tentativas:** fica em memória, por instância.
- **Segredos:** troque a senha do banco e o `JWT_SECRET`, use HTTPS e defina `CORS_ORIGIN`.

## Problemas comuns

| Sintoma | Solução |
|---|---|
| `JWT_SECRET não definido` | Crie o `.env` (passo 3) |
| `Can't reach database server` | Banco desligado ou porta errada no `DATABASE_URL` |
| `Authentication failed` | Senha errada. Lembre que `#` vira `%23` na URL |
| `failed to connect to the docker API` | Abra o Docker Desktop |
| `port is already allocated` ou porta 5432 em uso | Já há um PostgreSQL rodando: use-o (opção B) ou mude `POSTGRES_PORT` |
| `column ... does not exist` | Faltam migrações: `npm run db:deploy` |
| `EPERM` ao rodar `prisma generate` | Pare o `npm run dev` antes |
