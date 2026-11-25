import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// Cabeçalho das subtelas do Perfil: "‹ Perfil", título e subtítulo
class SubpageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const SubpageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: AppColors.tealDark,
                ),
                Text(
                  'Perfil',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.6,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// Card branco com título opcional e linhas separadas por divisórias
class SettingsCard extends StatelessWidget {
  final String? title;
  // Texto explicativo logo abaixo do título
  final String? description;
  final List<Widget> children;

  const SettingsCard({
    super.key,
    this.title,
    this.description,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final description = this.description;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (title != null || description != null) const SizedBox(height: 4),
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.ringTrack),
              children[i],
            ],
            if (children.isEmpty) const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// Linha de configuração: título, subtítulo e algo à direita
// (interruptor, valor em teal ou seta)
class SettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  // Null usa a cor do texto principal (muda com o tema)
  final Color? titleColor;

  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  // Seta "›" das linhas que abrem outra coisa
  static Widget get chevron =>
      Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.tealDark);

  // Valor atual em teal ("08:00", "Sistema")
  static Widget value(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.tealDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? AppColors.primaryDark,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// Linha com interruptor; tocar na linha inteira também alterna
class SettingsSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;

    return SettingsRow(
      title: title,
      subtitle: subtitle,
      onTap: onChanged == null ? null : () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

// Bottom sheet com uma lista de opções; devolve a escolhida ou null.
// Opções com `disabledHint` aparecem desativadas (ex.: "em breve").
Future<T?> showOptionsSheet<T>({
  required BuildContext context,
  required String title,
  required List<({T value, String label, String? disabledHint})> options,
  required T selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final option in options)
              ListTile(
                enabled: option.disabledHint == null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  option.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: option.disabledHint != null
                    ? Text(option.disabledHint!)
                    : null,
                trailing: option.value == selected
                    ? Icon(Icons.check_rounded, color: AppColors.tealDark)
                    : null,
                onTap: () => Navigator.pop(sheetContext, option.value),
              ),
          ],
        ),
      ),
    ),
  );
}

void showSettingsMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
