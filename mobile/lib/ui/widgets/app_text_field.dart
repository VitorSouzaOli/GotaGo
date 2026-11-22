import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

// Campo com rótulo acima, como nos formulários de login e cadastro.
// Com `isPassword`, mostra o ícone de olho para exibir/ocultar a senha.
class AppTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool isPassword;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  // Erro vindo do servidor (ex.: e-mail já cadastrado): borda e texto vermelhos
  final String? errorText;
  final String? suffixText;
  final int maxLines;
  // Campo só de leitura que abre outra coisa ao tocar (ex.: relógio)
  final VoidCallback? onTap;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.isPassword = false,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.errorText,
    this.suffixText,
    this.maxLines = 1,
    this.onTap,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword && _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          readOnly: widget.onTap != null,
          onTap: widget.onTap,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          minLines: widget.maxLines > 1 ? widget.maxLines : null,
          textCapitalization: widget.textCapitalization,
          style: TextStyle(fontSize: 16, color: AppColors.primaryDark),
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helperText,
            helperMaxLines: 2,
            errorText: widget.errorText,
            errorMaxLines: 2,
            suffixText: widget.suffixText,
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscured ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
