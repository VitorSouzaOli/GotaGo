import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

// Medalha das conquistas: duas fitas embaixo e o disco com aro.
// O ícone do centro e o selo (check/cadeado) ficam por cima, como widgets.
// Proporção ideal: 72 x 84.
class MedalPainter extends CustomPainter {
  final bool unlocked;

  const MedalPainter({required this.unlocked});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final radius = w / 2;
    final center = Offset(w / 2, radius);

    final ribbonColor = unlocked ? AppColors.dropDark : const Color(0xFFCFE3DF);
    final outerColor = unlocked ? AppColors.limeLight : AppColors.white;
    final innerColor = unlocked
        ? AppColors.limeAccent
        : AppColors.lockedSurface;
    final ringColor = unlocked ? AppColors.limeAccent : AppColors.outlineBorder;

    // Fitas com o corte em "V" na ponta
    for (final left in [w * 0.27, w * 0.53]) {
      final right = left + w * 0.2;
      final ribbon = Path()
        ..moveTo(left, radius * 1.4)
        ..lineTo(right, radius * 1.4)
        ..lineTo(right, h)
        ..lineTo((left + right) / 2, h - h * 0.08)
        ..lineTo(left, h)
        ..close();
      canvas.drawPath(ribbon, Paint()..color = ribbonColor);
    }

    // Disco externo, aro fino e disco interno
    canvas.drawCircle(center, radius, Paint()..color = outerColor);
    canvas.drawCircle(
      center,
      radius * 0.86,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(center, radius * 0.72, Paint()..color = innerColor);
  }

  @override
  bool shouldRepaint(covariant MedalPainter oldDelegate) {
    return oldDelegate.unlocked != unlocked;
  }
}
