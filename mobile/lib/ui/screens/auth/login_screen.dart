import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/arrow_label.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/footer_note.dart';
import '../../widgets/social_login.dart';
import '../home/home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _loginController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Remove Boas-vindas e Login da pilha: o "voltar" não retorna a elas
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } else {
      _showMessage(authProvider.errorMessage ?? 'Não foi possível entrar.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return AuthLayout(
      title: 'Bom te ver de novo!',
      subtitle:
          'Entre na sua conta e continue cuidando\ndo seu hábito, no seu ritmo.',
      footer: const FooterNote('Constância, não excesso. Respeite seu corpo.'),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'E-mail',
                  hint: 'Digite seu e-mail',
                  controller: _loginController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  // O backend também aceita username, então só exige preenchimento
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe seu e-mail'
                      : null,
                ),
                const SizedBox(height: 18),
                AppTextField(
                  label: 'Senha',
                  hint: 'Digite sua senha',
                  controller: _passwordController,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Informe sua senha'
                      : null,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showMessage('Recuperação de senha em breve.'),
            child: const Text('Esqueci minha senha'),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const ArrowLabel('Entrar'),
        ),
        const SizedBox(height: 24),
        const OrDivider(),
        const SizedBox(height: 24),
        GoogleButton(
          onPressed: () => _showMessage('Login com Google em breve.'),
        ),
      ],
    );
  }
}
