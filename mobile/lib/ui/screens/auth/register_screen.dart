import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/arrow_label.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/social_login.dart';
import '../home/home_shell.dart';

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

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().length < 2) {
      return 'Informe como você quer ser chamado';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Informe seu e-mail';
    if (!_emailRegex.hasMatch(value.trim())) return 'E-mail inválido';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    final hasLetter = password.contains(RegExp(r'[A-Za-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    if (password.length < 8 || !hasLetter || !hasNumber) {
      return 'Use pelo menos 8 caracteres, com letras e números.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } else {
      _showMessage(
        authProvider.errorMessage ?? 'Não foi possível criar sua conta.',
      );
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
      title: 'Bora começar?',
      subtitle:
          'Crie sua conta e faça da hidratação\num hábito. Um gole de cada vez.',
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
                  validator: _validateEmail,
                ),
                const SizedBox(height: 18),
                AppTextField(
                  label: 'Senha',
                  hint: 'Crie uma senha',
                  controller: _passwordController,
                  isPassword: true,
                  helperText:
                      'Use pelo menos 8 caracteres, com letras e números.',
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: _validatePassword,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
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
              : const ArrowLabel('Criar conta'),
        ),
        const SizedBox(height: 24),
        const OrDivider(),
        const SizedBox(height: 24),
        GoogleButton(
          onPressed: () => _showMessage('Cadastro com Google em breve.'),
        ),
      ],
    );
  }
}

class _TermsNote extends StatelessWidget {
  const _TermsNote();

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.tealDark,
    );

    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Ao criar sua conta, você concorda com os nossos\n'),
          TextSpan(text: 'Termos de uso', style: linkStyle),
          TextSpan(text: ' e a '),
          TextSpan(text: 'Política de privacidade', style: linkStyle),
          TextSpan(text: '.'),
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
