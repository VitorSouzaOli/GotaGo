import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/arrow_label.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/flow_page.dart';
import '../../widgets/social_login.dart';
import '../goal/goal_screens.dart';
import '../settings/legal_screens.dart';
import 'password_recovery_screens.dart';

// Cadastro: nome, e-mail e senha. A conta é criada na etapa seguinte,
// "Vamos encontrar seu ritmo", junto com a meta diária.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  // O servidor recusou o e-mail ("Você já tem uma conta")
  bool _emailInUse = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().length < 2) {
      return 'Informe como você quer ser chamado';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    // A regra completa aparece logo abaixo do campo de confirmação
    return validateNewPassword(value) == null
        ? null
        : 'A senha não atende à regra abaixo.';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final result = await pushPage<String>(
      context,
      GoalSetupScreen(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
    if (mounted && result == goalSetupEmailInUse) {
      setState(() => _emailInUse = true);
    }
  }

  void _goToLogin() {
    // Login fica logo abaixo das Boas-vindas: troca o Cadastro pelo Login
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: _emailInUse ? 'Você já tem uma conta' : 'Bora começar?',
      subtitle: _emailInUse ? 'Cadastro · E-mail já utilizado' : 'Crie sua conta e faça da hidratação\num hábito. Um gole de cada vez.',
      footer: const _TermsNote(),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Nome',
                  hint: 'Como você quer ser chamado?',
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: _validateName,
                ),
                const SizedBox(height: 18),
                AppTextField(
                  label: 'E-mail',
                  hint: 'Digite seu e-mail',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  helperText: 'Você usará este e-mail para entrar.',
                  errorText: _emailInUse
                      ? 'Já existe uma conta com este e-mail.'
                      : null,
                  onChanged: (_) {
                    if (_emailInUse) setState(() => _emailInUse = false);
                  },
                  validator: validateEmail,
                ),
                const SizedBox(height: 18),
                AppTextField(
                  label: 'Senha',
                  hint: 'Crie uma senha',
                  controller: _passwordController,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: _validatePassword,
                ),
                const SizedBox(height: 18),
                AppTextField(
                  label: 'Confirmar senha',
                  hint: 'Repita a senha',
                  controller: _confirmPasswordController,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validatePasswordConfirmation(
                    () => _passwordController.text,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 10),
                Text(
                  passwordRule,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_emailInUse) ...[
          const ErrorCard(
            title: 'Entre para continuar',
            body: 'Use sua conta existente ou recupere a senha.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _goToLogin,
            child: const Text('Ir para o login'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => pushPage(
              context,
              ForgotPasswordScreen(
                backLabel: 'Cadastro',
                initialEmail: _emailController.text.trim(),
              ),
            ),
            child: const Text('Recuperar minha senha'),
          ),
        ] else ...[
          FilledButton(
            onPressed: _submit,
            child: const ArrowLabel('Criar conta'),
          ),
          const SizedBox(height: 24),
          const OrDivider(),
          const SizedBox(height: 24),
          GoogleButton(
            onPressed: () =>
                showAppMessage(context, 'Cadastro com Google em breve.'),
          ),
        ],
      ],
    );
  }
}

class _TermsNote extends StatelessWidget {
  const _TermsNote();

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.tealDark,
    );

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Ao criar sua conta, você concorda com os nossos\n',
          ),
          TextSpan(
            text: 'Termos de uso',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => pushPage(context, const TermsScreen()),
          ),
          const TextSpan(text: ' e a '),
          TextSpan(
            text: 'Política de privacidade',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => pushPage(context, const PrivacyPolicyScreen()),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
    );
  }
}
