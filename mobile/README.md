# GotaGo: app mobile (Flutter)

App de hidratação em equipe. Este guia explica como rodar o app no seu computador
e conectá-lo ao backend da raiz do repositório. No final há a lista de rotas que o
app usa e as que ele ainda precisa.

## Pré-requisitos

| Ferramenta | Versão usada | Observação |
|---|---|---|
| Flutter SDK | 3.47.8 (stable) | Já inclui o Dart. Confira com `flutter --version` |
| Android Studio | qualquer recente | Instale o Android SDK e crie um emulador no *Device Manager* |
| Backend do GotaGo | — | Precisa estar rodando na porta **3333** (ver abaixo) |

Rode `flutter doctor` e verifique se aparece ✓ em **Flutter** e **Android toolchain**.

> **iOS:** compilar para iPhone exige um Mac com Xcode. No Windows ou no Linux, use
> o emulador Android.

## Como rodar

### 1. Suba o backend

Na **raiz** do repositório:

```bash
docker compose up -d   # Postgres
npm install
npm run dev            # API em http://localhost:3333
```

Confira se a API respondeu abrindo `http://localhost:3333/health`. Deve aparecer
`{"status":"ok"}`.

### 2. Rode o app

Com o emulador Android aberto, em outro terminal:

```bash
cd mobile
flutter pub get
flutter run --dart-define=MOCK_API=false
```

> **Atenção:** o `flutter run` puro abre o app no **modo demo**, com dados falsos e sem
> chamar o backend (ver abaixo). Pra testar com a API, use sempre
> `--dart-define=MOCK_API=false`. No VS Code, escolha a configuração
> **"GotaGo (API real)"** em *Run and Debug*.

O app abre na splash animada. Depois vem a tela de boas-vindas. Crie uma conta e
você chega na Home.

- **Reiniciar a sessão:** o login fica salvo no aparelho, então nas próximas
  aberturas o app vai direto pra Home. Pra sair, use **Perfil → Sair da conta**.
- **Durante o desenvolvimento:** `r` no terminal faz hot reload e `R` faz hot restart.
  Mudanças no `pubspec.yaml`, nas fontes ou no ícone exigem parar e rodar
  `flutter run` de novo.

### Modo demo (sem backend)

| Comando | Modo |
|---|---|
| `flutter run` | **Demo** (padrão em debug) |
| `flutter run --dart-define=MOCK_API=false` | API real |
| `flutter build ...` (release) | API real, a menos que passe `MOCK_API=true` |

No modo demo, o [`MockApiInterceptor`](lib/services/mock_api_interceptor.dart)
responde com dados falsos às rotas de cadastro, login, registro de água e
conquistas, e aparece uma faixa **DEMO** no canto da tela.

- **Login:** qualquer e-mail e senha entram como "Vitor Souza", com meta de
  2.500 ml e 6 dias de constância.
- **Dados:** ficam só na memória e somem quando o app é fechado.
- **Sessão:** ao abrir com a API real, uma sessão salva no modo demo é descartada
  automaticamente e o app pede login de novo.

### Endereço da API

O endereço fica em [`lib/services/api_service.dart`](lib/services/api_service.dart):

```dart
static const String _baseUrl = 'http://10.0.2.2:3333';
```

| Onde o app roda | Valor de `_baseUrl` |
|---|---|
| Emulador Android | `http://10.0.2.2:3333` (padrão; é o `localhost` do PC visto de dentro do emulador) |
| Celular físico no mesmo Wi-Fi | `http://<IP do PC>:3333` (veja o IP com `ipconfig` ou `ip a`) |
| Simulador iOS / Web | `http://localhost:3333` |

Num celular físico também é preciso liberar a porta 3333 no firewall do PC.

## Testes e análise

```bash
cd mobile
flutter analyze   # lint e erros de tipo
flutter test      # testes unitários e de navegação
```

## Estrutura

```
mobile/
├── assets/fonts/        Plus Jakarta Sans embutida (licença SIL OFL)
├── branding/            PNGs do logo e do ícone do app (fonte do ícone)
├── lib/
│   ├── main.dart        Providers e MaterialApp
│   ├── core/theme/      Cores (app_colors) e tema Material 3 (app_theme)
│   ├── core/utils/      Formatadores ("1.250 ml", "09:20", saudação)
│   ├── models/          UserModel, AchievementModel
│   ├── services/        ApiService: Dio, storage local e tradução de erros
│   ├── providers/       AuthProvider, WaterProvider, AchievementProvider
│   └── ui/
│       ├── painters/    CustomPainters: gota, ondas, troféu, anel, logo do Google
│       ├── widgets/     Componentes reutilizáveis (logo, campos, layout de auth)
│       └── screens/     splash, welcome, auth (login/cadastro), home
└── test/
```

**Fluxo de telas:** Splash → Boas-vindas → Cadastro ou Login → Home (abas Início,
Ligas, Histórico e Perfil).

## Integração com o backend

### Rotas que o app usa hoje

| Rota | Onde | Body enviado | O que o app lê da resposta |
|---|---|---|---|
| `POST /users` | Cadastro | `name`, `username`, `email`, `password` | `user` |
| `POST /sessions` | Login | `login` (e-mail ou username), `password` | `user` |
| `POST /water-logs` | Home: botões "+ ml" | `userId`, `amount` | `totalToday`, `dailyGoal`, `waterLog.createdAt`, `streakUpdated`, `newAchievements`, `warning` |
| `GET /users/:userId/achievements` | Home: card Conquistas | — | `achievements[]` com `name`, `isUnlocked`, `unlockedAt` |

O objeto `user` é lido com os campos `id`, `name`, `username`, `email`,
`avatarUrl`, `weight`, `dailyGoal`, `currentStreak` e `maxStreak`
(ver [`lib/models/user_model.dart`](lib/models/user_model.dart)).

**Mensagens de erro:** o app traduz alguns textos do campo `{ "error": "..." }`.
Se você mudar esses textos no backend, atualize também o mapeamento no
[`auth_provider.dart`](lib/providers/auth_provider.dart):

| Texto que o backend envia | Mensagem que o app mostra |
|---|---|
| `Invalid credentials` | "E-mail ou senha incorretos." |
| `Email already exists` | "Este e-mail já está cadastrado." |
| `Username already exists` | O app tenta de novo com um sufixo numérico no username |

Qualquer outro erro aparece como uma mensagem genérica. Sem resposta do servidor, o
app mostra "Não foi possível conectar ao servidor".

### O que o app ainda precisa do backend

São soluções provisórias no app, cada uma esperando uma rota:

| Necessidade | Situação atual no app | Rota sugerida |
|---|---|---|
| Total consumido hoje | Guardado **só no aparelho** (`WaterProvider`) e zerado na virada do dia. Registros feitos em outro aparelho não aparecem | `GET /users/:userId/water-logs/today` → `{ totalToday, dailyGoal, lastLog }` |
| Ligas do usuário | A Home mostra o estado vazio "Nenhuma liga ainda" | `GET /users/:userId/leagues` |
| Dados atualizados do usuário | A sessão usa o `user` salvo no login; streak e meta podem ficar desatualizados | `GET /me` (com JWT) |
| Autenticação | Sem token: o app envia `userId` no body. O `ApiService` já lê `jwt_token` do storage e envia `Authorization: Bearer` se ele existir | `POST /sessions` devolver `token` |
| Editar meta | Botão "Editar meta" mostra "em breve" | `PATCH /me` com `dailyGoal` |
| Cadastro sem username | A tela não pede username. O app gera a partir do e-mail (`vitor@...` → `vitor`) | Tornar `username` opcional no `POST /users`, ou manter assim |
| Google, recuperação de senha | Botões mostram "em breve" | — |
| App rodando na web | O navegador bloqueia as chamadas | Registrar o `@fastify/cors` no `server.ts` |

Quando o JWT existir: salve o token com a chave `jwt_token` no
`FlutterSecureStorage`, que o interceptor do `ApiService` já está pronto. Depois
remova o `userId` dos bodies.

## Ícone do app

A configuração está no fim do `pubspec.yaml`. Pra regerar o ícone depois de
trocar os PNGs em `branding/`:

```bash
dart run flutter_launcher_icons
```

Depois de rodar, **confira o `ios/Runner.xcodeproj/project.pbxproj`**. Um bug do
pacote troca `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`
por `AppIcon`. Se isso acontecer, desfaça essa mudança com
`git checkout -- ios/Runner.xcodeproj/project.pbxproj`.

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| "Não foi possível conectar ao servidor" | Backend parado, `_baseUrl` errado pro dispositivo ou firewall bloqueando a porta 3333 |
| "Não foi possível criar sua conta" / "Não foi possível entrar" | Erro no backend: veja o terminal do `npm run dev` |
| Backend falha ao conectar no banco | Confira se o nome do banco no `DATABASE_URL` do `.env` bate com o `POSTGRES_DB` do `docker-compose.yml`, e rode `npx prisma migrate dev` |
| Tela vazia e log com "Another exception was thrown" | Role o log até o **primeiro** `EXCEPTION CAUGHT BY…`: é lá que está a causa |
| Ícone antigo continua aparecendo | Desinstale o app do emulador e rode `flutter run` de novo |
