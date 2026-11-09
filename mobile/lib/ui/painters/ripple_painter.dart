import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class RipplePainter extends CustomPainter {
  // 0 = antes do impacto da gota, 1 = ondas abertas e suavizadas (estado final)
  final double progress;

  RipplePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = size.center(Offset.zero);

    // Dois anéis achatados (elipses): o externo nasce primeiro, o interno logo depois
    for (int i = 0; i < 2; i++) {
      final t = ((progress - i * 0.12) / 0.6).clamp(0.0, 1.0);
      if (t == 0) continue;

      final expand = Curves.easeOutCubic.transform(t);
      final ringScale = i == 0 ? 1.0 : 0.82;
      final growth = 0.3 + 0.7 * expand;

      // Aparece forte no impacto e suaviza até ficar discreto no final
      final fadeIn = (t / 0.15).clamp(0.0, 1.0);
      final soften = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
      final opacity = fadeIn * (0.9 - 0.45 * soften);

      final paint = Paint()
        ..color = AppColors.ripple.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * ringScale * growth,
          height: size.height * ringScale * growth,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
