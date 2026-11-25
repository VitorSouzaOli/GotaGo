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

Siga o [README da raiz](../README.md) (banco, `.env`, migrações). Depois, na **raiz**:

```bash
npm run dev            # API em http://localhost:3333
```

Confira se a API respondeu abrindo `http://localhost:3333/health`. Deve aparecer
`{"status":"ok","service":"GotaGo API"}`.

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
- **Ligas:** "Time do gole" e "Gotas do trabalho" já vêm prontas. O código
  `RITMO6` entra na liga "Ritmo de água"; qualquer outro código mostra o erro.
- **Cadastro:** o e-mail `vitor@exemplo.com` simula "e-mail já cadastrado".
- **Recuperar senha:** em "Confira seu e-mail" aparece o atalho
  "Abrir o link do e-mail (demo)", que faz o papel do link recebido.
- **Suporte:** cada solicitação recebe uma resposta automática da "Equipe GotaGo".
- **Dados:** ficam só na memória e somem quando o app é fechado.
- **Sessão:** ao abrir com a API real, uma sessão salva no modo demo é descartada
  automaticamente e o app pede login de novo.

### Endereço da API

O app escolhe o endereço sozinho e aceita a flag `API_URL`:

| Onde o app roda | Endereço |
|---|---|
| Emulador Android | `http://10.0.2.2:3333` (automático; é o `localhost` do PC visto do emulador) |
| Navegador, Windows desktop ou simulador iOS | `http://localhost:3333` (automático) |
| Celular físico no mesmo Wi-Fi | `--dart-define=API_URL=http://<IP do PC>:3333` (veja o IP com `ipconfig`) |

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
│       ├── navigation/  ShellController: aba ativa, usado pelas telas de fluxo
│       └── screens/     splash, welcome, auth, goal, water, home, leagues, history,
│                        profile, achievements, support, settings, common
│                        (as telas de fluxo usam o molde widgets/flow_page.dart)
└── test/
```

**Fluxo de telas:** Splash → Boas-vindas → Cadastro ou Login → Home (abas Início,
Ligas, Histórico e Perfil).

## Integração com o backend

As rotas estão documentadas no [README da raiz](../README.md#rotas-da-api). O login e o
cadastro devolvem um token, que o app guarda no `FlutterSecureStorage` (chave
`jwt_token`) e envia em `Authorization: Bearer`. Quando o servidor responde 401
(token expirado), o app sai da conta e volta para as boas-vindas.

**Mensagens de erro:** o app traduz alguns textos do campo `{ "error": "..." }`.
Se você mudar esses textos no backend, atualize também o app:

| Texto que o backend envia | Mensagem que o app mostra |
|---|---|
| `Invalid credentials` | Tela "Vamos tentar de novo?" (no login) / "A senha atual está incorreta." (alterar senha) |
| `Email already exists` | Tela "Você já tem uma conta" |
| `Username already exists` | O app tenta de novo com um sufixo numérico no username |
| `Liga não encontrada com este código.` | "Nenhuma liga encontrada com esse código." |
| `Já fazes parte desta liga.` | "Você já faz parte desta liga." |

### O que ainda é só do aparelho

| Função | Situação |
|---|---|
| Login com Google, foto do perfil, anexos no suporte | Mostram "em breve" |
| Lembretes, preferências e privacidade | Salvos no aparelho; o app ainda não dispara notificações |
| Suporte e pedido de cópia dos dados | Ficam registrados no aparelho |
| Recuperação de senha | O link abre uma página servida pela API. Sem provedor de e-mail, ele aparece no terminal do servidor |

## Tema claro e escuro

Em Perfil → Preferências → Aparência: Claro, Escuro ou Sistema. As cores ficam
em [`app_colors.dart`](lib/core/theme/app_colors.dart): as da marca são
constantes, e as de superfície e texto são *getters* que mudam com o tema. Por
isso elas **não podem ser usadas em `const`** (o analisador acusa). Ao trocar o
tema, o `main.dart` reconstrói toda a árvore.

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
| Backend falha ao conectar no banco | Veja "Problemas comuns" no [README da raiz](../README.md#problemas-comuns) |
| Tela vazia e log com "Another exception was thrown" | Role o log até o **primeiro** `EXCEPTION CAUGHT BY…`: é lá que está a causa |
| Ícone antigo continua aparecendo | Desinstale o app do emulador e rode `flutter run` de novo |
