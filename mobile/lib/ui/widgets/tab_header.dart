import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'gotago_logo.dart';

// Cabeçalho das abas: logo pequeno, título grande e subtítulo.
// `trailing` fica à direita do logo (ex.: avatar na aba Ligas).
class TabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const TabHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const GotaGoLogo(fontSize: 24, showSubtitle: false),
            const Spacer(),
            ?trailing,
          ],
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.6,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
