import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

// Texto do botão principal com a seta verde-amarelada ("Entrar →")
class ArrowLabel extends StatelessWidget {
  final String text;

  const ArrowLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text),
        const SizedBox(width: 10),
        const Icon(
          Icons.arrow_forward_rounded,
          size: 20,
          color: AppColors.limeAccent,
        ),
      ],
    );
  }
}
