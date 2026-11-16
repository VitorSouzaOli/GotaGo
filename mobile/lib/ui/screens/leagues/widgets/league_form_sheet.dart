import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../widgets/app_text_field.dart';

enum LeagueFormMode { create, join }

// O que o utilizador preencheu: nome/descrição (criar) ou código (entrar)
class LeagueFormResult {
  final String name;
  final String? description;
  final String code;

  LeagueFormResult({this.name = '', this.description, this.code = ''});
}

// Bottom sheet de "Criar liga" ou "Entrar com código"; devolve null se cancelar
Future<LeagueFormResult?> showLeagueFormSheet(
  BuildContext context,
  LeagueFormMode mode,
) {
  return showModalBottomSheet<LeagueFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _LeagueFormSheet(mode: mode),
  );
}

class _LeagueFormSheet extends StatefulWidget {
  final LeagueFormMode mode;

  const _LeagueFormSheet({required this.mode});

  @override
  State<_LeagueFormSheet> createState() => _LeagueFormSheetState();
}

class _LeagueFormSheetState extends State<_LeagueFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();

  bool get _isCreate => widget.mode == LeagueFormMode.create;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final description = _descriptionController.text.trim();
    Navigator.pop(
      context,
      _isCreate
          ? LeagueFormResult(
              name: _nameController.text.trim(),
              description: description.isEmpty ? null : description,
            )
          : LeagueFormResult(code: _codeController.text.trim().toUpperCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isCreate ? 'Criar liga' : 'Entrar com código',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isCreate
                  ? 'Depois é só compartilhar o código de convite com seus amigos.'
                  : 'Peça o código para quem criou a liga.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            if (_isCreate) ...[
              AppTextField(
                label: 'Nome da liga',
                hint: 'Ex.: Time do gole',
                controller: _nameController,
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.trim().length < 3)
                    ? 'Use pelo menos 3 caracteres'
                    : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Descrição (opcional)',
                hint: 'Do que se trata a liga?',
                controller: _descriptionController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ] else
              AppTextField(
                label: 'Código da liga',
                hint: 'Ex.: GOTA-8X91',
                controller: _codeController,
                textInputAction: TextInputAction.done,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe o código'
                    : null,
                onSubmitted: (_) => _submit(),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: Text(_isCreate ? 'Criar liga' : 'Entrar na liga'),
            ),
          ],
        ),
      ),
    );
  }
}
