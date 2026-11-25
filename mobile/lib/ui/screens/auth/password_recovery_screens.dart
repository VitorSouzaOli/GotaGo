import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/flow_page.dart';
import '../common/status_screens.dart';

// Nome da rota do Login, para "Voltar para entrar" achar a tela
const loginRouteName = 'login';

// Fecha a recuperação e volta para o Login (ou para a primeira tela, se a
// recuperação foi aberta de dentro do app, em Privacidade e segurança)
void popToLogin(BuildContext context) {
  Navigator.of(
    context,
  ).popUntil((route) => route.settings.name == loginRouteName || route.isFirst);
}

// "Esqueceu sua senha?"
class ForgotPasswordScreen extends StatefulWidget {
  final String backLabel;
  final String initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.backLabel = 'Login',
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final ok = await auth.requestPasswordReset(email);
    if (!mounted) return;

    if (ok) {
      replacePage(context, CheckEmailScreen(email: email));
    } else if (auth.failure == AuthFailure.offline) {
      showOffline(context, _submit);
    } else {
      showAppMessage(context, auth.errorMessage ?? 'Não foi possível enviar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return FlowPage(
      backLabel: widget.backLabel,
      title: 'Esqueceu sua senha?',
      subtitle: 'Vamos ajudar você a recuperar o acesso.',
      content: [
        Form(
          key: _formKey,
          child: AppTextField(
            label: 'E-mail da conta',
            hint: 'Seu e-mail',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            helperText: 'Enviaremos as instruções para redefinir sua senha.',
            validator: validateEmail,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const FlowCard(
          title: 'Um acesso seguro',
          body: 'Você receberá um link para criar uma nova senha.',
        ),
        const NoteCard(
          'Se você usa o Google, pode continuar com sua conta Google na tela '
          'de login.',
        ),
      ],
      primary: FlowAction('Enviar instruções', _submit, loading: isLoading),
      secondary: FlowAction('Voltar para entrar', () => popToLogin(context)),
    );
  }
}

// "Confira seu e-mail"
class CheckEmailScreen extends StatelessWidget {
  final String email;

  const CheckEmailScreen({super.key, required this.email});

  Future<void> _resend(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.requestPasswordReset(email);
    if (!context.mounted) return;
    showAppMessage(
      context,
      ok
          ? 'Enviamos as instruções de novo.'
          : auth.errorMessage ?? 'Não foi possível reenviar.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      title: 'Confira seu e-mail',
      subtitle: 'Seu próximo passo está na caixa de entrada.',
      illustration: const DropIllustration(),
      content: [
        const FlowCard(
          title: 'Instruções enviadas',
          body:
              'Se existir uma conta com o e-mail informado, você receberá um '
              'link para criar uma nova senha.',
        ),
        const NoteCard(
          'Confira também as pastas de spam e lixo eletrônico. Não '
          'compartilhe o link recebido.',
        ),
        // Na demo não há e-mail: este atalho faz o papel do link recebido
        if (ApiService.useMock)
          Center(
            child: TextButton.icon(
              onPressed: () =>
                  pushPage(context, const NewPasswordScreen(token: 'demo')),
              icon: Icon(Icons.mail_outline_rounded, color: AppColors.tealDark),
              label: const Text('Abrir o link do e-mail (demo)'),
            ),
          ),
      ],
      primary: FlowAction('Voltar para entrar', () => popToLogin(context)),
      secondary: FlowAction('Reenviar instruções', () => _resend(context)),
    );
  }
}

// "Crie uma nova senha" (aberta pelo link do e-mail)
class NewPasswordScreen extends StatefulWidget {
  final String token;

  const NewPasswordScreen({super.key, required this.token});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.resetPassword(widget.token, _passwordController.text);
    if (!mounted) return;

    if (ok) {
      replacePage(context, const PasswordUpdatedScreen());
    } else if (auth.failure == AuthFailure.offline) {
      showOffline(context, _submit);
    } else {
      showAppMessage(context, auth.errorMessage ?? 'Não foi possível salvar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return FlowPage(
      title: 'Crie uma nova senha',
      subtitle: 'Uma senha exclusiva para sua conta.',
      content: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Nova senha',
                hint: 'Crie uma senha',
                controller: _passwordController,
                isPassword: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                helperText: passwordRule,
                validator: validateNewPassword,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Confirmar nova senha',
                hint: 'Repita a senha',
                controller: _confirmController,
                isPassword: true,
                textInputAction: TextInputAction.done,
                helperText: 'Repita a mesma senha.',
                validator: validatePasswordConfirmation(
                  () => _passwordController.text,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const NoteCard('Evite reutilizar senhas de outros serviços.'),
      ],
      primary: FlowAction('Salvar nova senha', _submit, loading: isLoading),
      secondary: FlowAction('Voltar para entrar', () => popToLogin(context)),
    );
  }
}

// "Senha atualizada!"
class PasswordUpdatedScreen extends StatelessWidget {
  const PasswordUpdatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      title: 'Senha atualizada!',
      subtitle: 'Tudo pronto para voltar à sua rotina.',
      onBack: () => popToLogin(context),
      illustration: const DropIllustration(),
      content: const [
        FlowCard(
          title: 'Acesso recuperado',
          body:
              'Sua nova senha foi salva. Entre novamente para continuar '
              'acompanhando sua hidratação.',
        ),
        NoteCard('Não foi você? Procure ajuda na central de suporte.'),
      ],
      primary: FlowAction('Entrar na minha conta', () => popToLogin(context)),
    );
  }
}
