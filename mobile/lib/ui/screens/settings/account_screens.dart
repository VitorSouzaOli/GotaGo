import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/validators.dart';
import '../../../providers/achievement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/league_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/water_provider.dart';
import '../../../services/api_service.dart';
import '../../navigation/shell_controller.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/flow_page.dart';
import '../auth/password_recovery_screens.dart';
import '../common/status_screens.dart';
import '../support/support_screens.dart';
import '../welcome/welcome_screen.dart';
import 'widgets/settings_widgets.dart';

const _privacyBack = 'Privacidade e segurança';

// "Métodos de acesso"
class AccessMethodsScreen extends StatelessWidget {
  const AccessMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().user?.email ?? '';

    return FlowPage(
      title: 'Métodos de acesso',
      subtitle: 'Escolha como entrar na sua conta.',
      content: [
        FlowCard(
          title: 'E-mail e senha',
          body: 'Senha configurada · Alterar senha',
          onTap: () => pushPage(context, const ChangePasswordScreen()),
        ),
        FlowCard(
          title: 'Conta Google',
          body: 'Não vinculada · Vincular com Google',
          onTap: () => showAppMessage(context, 'Login com Google em breve.'),
        ),
        const NoteCard(
          'Vincule apenas uma conta que pertença a você. Seu histórico e suas '
          'conquistas continuam na mesma conta.',
        ),
        FlowCard(
          title: 'Precisa recuperar o acesso?',
          body: 'Receber instruções por e-mail',
          onTap: () => pushPage(
            context,
            ForgotPasswordScreen(backLabel: 'Voltar', initialEmail: email),
          ),
        ),
      ],
      primary: FlowAction('Voltar à segurança', () => Navigator.pop(context)),
    );
  }
}

// "Alterar senha"
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(
      _currentController.text,
      _newController.text,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      showAppMessage(context, 'Senha alterada.');
    } else if (auth.failure == AuthFailure.offline) {
      showOffline(context, _save);
    } else {
      showAppMessage(context, auth.errorMessage ?? 'Não foi possível salvar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return FlowPage(
      title: 'Alterar senha',
      subtitle: 'Mantenha seu acesso protegido.',
      content: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Senha atual',
                hint: 'Digite sua senha atual',
                controller: _currentController,
                isPassword: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.password],
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Informe sua senha atual'
                    : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => pushPage(
                    context,
                    ForgotPasswordScreen(
                      backLabel: 'Voltar',
                      initialEmail: auth.user?.email ?? '',
                    ),
                  ),
                  child: const Text('Esqueceu sua senha? Recuperar acesso'),
                ),
              ),
              AppTextField(
                label: 'Nova senha',
                hint: 'Crie uma senha',
                controller: _newController,
                isPassword: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                helperText: 'Pelo menos 8 caracteres, com letras e números.',
                validator: validateNewPassword,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Confirmar nova senha',
                hint: 'Repita a nova senha',
                controller: _confirmController,
                isPassword: true,
                textInputAction: TextInputAction.done,
                helperText: 'Repita a nova senha.',
                validator: validatePasswordConfirmation(
                  () => _newController.text,
                ),
                onSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
        const NoteCard('Use uma senha exclusiva e nunca a compartilhe.'),
      ],
      primary: FlowAction('Salvar nova senha', _save, loading: auth.isLoading),
      secondary: FlowAction('Cancelar', () => Navigator.pop(context)),
    );
  }
}

// "Dispositivos conectados". O backend ainda não registra sessões; na demo
// aparece uma sessão de exemplo em outro aparelho.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  late List<String> _otherSessions = ApiService.useMock
      ? ['Safari no computador']
      : [];

  String get _thisDevice {
    if (kIsWeb) return 'Este navegador';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'Este iPhone',
      TargetPlatform.android => 'Este Android',
      _ => 'Este aparelho',
    };
  }

  void _endSession(String session) {
    setState(() => _otherSessions = [..._otherSessions]..remove(session));
    showAppMessage(context, 'Sessão encerrada: $session.');
  }

  void _endAll() {
    if (_otherSessions.isEmpty) {
      showAppMessage(context, 'Não há outras sessões ativas.');
      return;
    }
    setState(() => _otherSessions = []);
    showAppMessage(context, 'Outras sessões encerradas.');
  }

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      title: 'Dispositivos conectados',
      subtitle: 'Reconheça os acessos à sua conta.',
      content: [
        FlowCard(title: _thisDevice, body: 'Sessão atual · Ativo agora'),
        for (final session in _otherSessions)
          FlowCard(
            title: session,
            body: 'Outro dispositivo · Encerrar sessão',
            onTap: () => _endSession(session),
          ),
        const NoteCard(
          'Não reconhece um acesso? Encerre a sessão e altere sua senha. Sua '
          'sessão atual será mantida.',
        ),
      ],
      primary: FlowAction('Encerrar outras sessões', _endAll),
      secondary: FlowAction(
        'Alterar minha senha',
        () => pushPage(context, const ChangePasswordScreen()),
      ),
    );
  }
}

// "Seus dados, com você": pedido de cópia dos dados
class DataCopyScreen extends StatelessWidget {
  const DataCopyScreen({super.key});

  Future<void> _request(BuildContext context) async {
    final provider = context.read<SettingsProvider>();
    await provider.update(
      provider.settings.copyWith(dataExportRequestedAt: DateTime.now()),
    );
    if (context.mounted) replacePage(context, const DataCopyRequestedScreen());
  }

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      backLabel: _privacyBack,
      title: 'Seus dados, com você',
      subtitle: 'Solicite uma cópia das informações da sua conta.',
      content: const [
        FlowCard(
          title: 'O que estará na cópia?',
          body:
              'Dados do perfil, metas de hidratação, registros de consumo e '
              'participação em ligas.',
        ),
        FlowCard(
          title: 'Como funciona',
          body:
              'Confirme sua solicitação. Você será avisado quando a cópia '
              'estiver disponível para acesso seguro.',
        ),
        NoteCard(
          'O arquivo pode conter informações pessoais. Guarde-o em um local '
          'privado.',
        ),
      ],
      primary: FlowAction('Solicitar cópia dos dados', () => _request(context)),
      secondary: FlowAction('Cancelar', () => Navigator.pop(context)),
    );
  }
}

// "Solicitação recebida"
class DataCopyRequestedScreen extends StatelessWidget {
  const DataCopyRequestedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      backLabel: _privacyBack,
      title: 'Solicitação recebida',
      subtitle: 'Sua cópia de dados será preparada.',
      content: [
        const FlowCard(
          title: 'Pedido em processamento',
          body:
              'Você será avisado quando a cópia estiver disponível. Não é '
              'necessário solicitar novamente.',
        ),
        if (!ApiService.useMock)
          const NoteCard(
            'A exportação ainda não está conectada ao servidor: o pedido fica '
            'registrado neste aparelho.',
          ),
        const NoteCard(
          'Continue usando o GotaGo normalmente. Este pedido não exclui sua '
          'conta.',
        ),
      ],
      primary: FlowAction('Voltar à privacidade', () => Navigator.pop(context)),
      secondary: FlowAction(
        'Falar com o suporte',
        () => replacePage(context, const SupportFormScreen()),
      ),
    );
  }
}

// "Excluir sua conta?": só libera o botão depois de digitar EXCLUIR
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmed => _controller.text.trim().toUpperCase() == 'EXCLUIR';

  Future<void> _delete() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.deleteAccount();
    if (!mounted) return;

    if (!ok) {
      if (auth.failure == AuthFailure.offline) {
        showOffline(context, _delete);
      } else {
        showAppMessage(
          context,
          auth.errorMessage ?? 'Não foi possível excluir.',
        );
      }
      return;
    }

    context.read<WaterProvider>().clear();
    context.read<AchievementProvider>().clear();
    context.read<LeagueProvider>().clear();
    context.read<SettingsProvider>().clear();
    context.read<ShellController>().reset();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
    showAppMessage(context, 'Sua conta foi excluída.');
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return FlowPage(
      backLabel: _privacyBack,
      title: 'Excluir sua conta?',
      subtitle: 'Essa decisão merece um momento de atenção.',
      content: [
        const FlowCard(
          title: 'O que você perde',
          body:
              'Seu acesso ao perfil, histórico de hidratação, conquistas e '
              'participação nas ligas será encerrado.',
        ),
        const NoteCard(
          'Esta ação não pode ser desfeita. Dados que precisem ser mantidos '
          'por obrigação legal seguem a política aplicável.',
        ),
        FlowCard(
          title: 'Antes de continuar',
          body:
              'Você pode solicitar uma cópia dos seus dados pela tela de '
              'Privacidade e segurança.',
          onTap: () => pushPage(context, const DataCopyScreen()),
        ),
        AppTextField(
          label: 'Digite EXCLUIR para confirmar',
          hint: 'EXCLUIR',
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          helperText: 'Nunca compartilhe sua senha ou códigos de acesso.',
          onChanged: (_) => setState(() {}),
        ),
      ],
      primary: FlowAction(
        'Excluir minha conta',
        _confirmed ? _delete : null,
        destructive: true,
        loading: isLoading,
      ),
      secondary: FlowAction('Manter minha conta', () => Navigator.pop(context)),
    );
  }
}

// "Visibilidade do perfil": o que os amigos veem nas ligas
class ProfileVisibilityScreen extends StatefulWidget {
  const ProfileVisibilityScreen({super.key});

  @override
  State<ProfileVisibilityScreen> createState() =>
      _ProfileVisibilityScreenState();
}

class _ProfileVisibilityScreenState extends State<ProfileVisibilityScreen> {
  late final _initial = context.read<SettingsProvider>().settings;
  late bool _photo = _initial.photoInLeagues;
  late bool _volume = _initial.shareVolume;

  Future<void> _pick(int row) async {
    if (row == 0) {
      showAppMessage(
        context,
        'Nome e constância aparecem sempre: são a base do ranking.',
      );
      return;
    }

    final isPhoto = row == 1;
    final picked = await showOptionsSheet<bool>(
      context: context,
      title: isPhoto ? 'Foto nas ligas' : 'Volume consumido',
      selected: isPhoto ? _photo : _volume,
      options: isPhoto
          ? const [
              (value: true, label: 'Exibir', disabledHint: null),
              (value: false, label: 'Ocultar', disabledHint: null),
            ]
          : const [
              (value: false, label: 'Não compartilhar', disabledHint: null),
              (value: true, label: 'Compartilhar', disabledHint: null),
            ],
    );
    if (picked == null) return;
    setState(() => isPhoto ? _photo = picked : _volume = picked);
  }

  Future<void> _save() async {
    final provider = context.read<SettingsProvider>();
    await provider.update(
      provider.settings.copyWith(photoInLeagues: _photo, shareVolume: _volume),
    );
    if (!mounted) return;
    Navigator.pop(context);
    showAppMessage(context, 'Preferências de visibilidade salvas.');
  }

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      backLabel: _privacyBack,
      title: 'Visibilidade do perfil',
      subtitle: 'Compartilhe apenas o que faz sentido.',
      content: [
        InfoRowsCard(
          rows: [
            ('Nome e constância', 'Nas suas ligas'),
            ('Foto nas ligas', _photo ? 'Exibir' : 'Ocultar'),
            ('Volume consumido', _volume ? 'Compartilhar' : 'Não compartilhar'),
          ],
          onTapRow: _pick,
        ),
        const FlowCard(
          title: 'Uma competição mais saudável',
          body:
              'As ligas mostram sua sequência de dias. O histórico detalhado '
              'de consumo é pessoal.',
        ),
        const NoteCard(
          'Seu nome é necessário para que os participantes reconheçam você na '
          'classificação.',
        ),
      ],
      primary: FlowAction('Salvar preferências', _save),
      secondary: FlowAction('Cancelar', () => Navigator.pop(context)),
    );
  }
}
