import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../painters/google_logo_painter.dart';

// Separador "—— ou ——"
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.outlineBorder)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ou',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Divider(color: AppColors.outlineBorder)),
      ],
    );
  }
}

class GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(backgroundColor: AppColors.white),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(size: Size(22, 22), painter: GoogleLogoPainter()),
          SizedBox(width: 12),
          Text('Continuar com o Google'),
        ],
      ),
    );
  }
}
