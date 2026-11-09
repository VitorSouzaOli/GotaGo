import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'drop_painter.dart';

// Troféu da tela de boas-vindas: taça em formato de gota, alças, haste,
// prato verde-amarelado e base verde-petróleo. Proporção ideal: 220 x 190.
class TrophyPainter extends CustomPainter {
  const TrophyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sombra no chão
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.935),
        width: w * 0.8,
        height: h * 0.07,
      ),
      Paint()..color = AppColors.dropDark.withValues(alpha: 0.10),
    );

    // Alças (desenhadas antes da taça, que fica por cima)
    final handlePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.dropLight, AppColors.dropDark],
      ).createShader(Rect.fromLTWH(0, h * 0.2, w, h * 0.4))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;

    for (final side in [-1.0, 1.0]) {
      double x(double f) => w * (0.5 + side * (0.5 - f));

      final handle = Path()
        ..moveTo(x(0.36), h * 0.30)
        ..cubicTo(x(0.24), h * 0.22, x(0.18), h * 0.34, x(0.22), h * 0.43)
        ..cubicTo(x(0.26), h * 0.51, x(0.33), h * 0.54, x(0.38), h * 0.56);

      canvas.drawPath(handle, handlePaint);
    }

    // Haste: estreita embaixo da taça e abrindo até o prato
    final stem = Path()
      ..moveTo(w * 0.465, h * 0.62)
      ..lineTo(w * 0.535, h * 0.62)
      ..quadraticBezierTo(w * 0.535, h * 0.74, w * 0.58, h * 0.775)
      ..lineTo(w * 0.42, h * 0.775)
      ..quadraticBezierTo(w * 0.465, h * 0.74, w * 0.465, h * 0.62)
      ..close();

    canvas.drawPath(
      stem,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.dropDark, AppColors.primaryDarkLight],
        ).createShader(Rect.fromLTWH(0, h * 0.62, w, h * 0.16)),
    );

    // Taça em formato de gota
    paintDrop(canvas, Rect.fromLTWH(w * 0.30, 0, w * 0.40, h * 0.66));

    // Prato verde-amarelado
    final plateRect = Rect.fromLTRB(w * 0.29, h * 0.765, w * 0.71, h * 0.805);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plateRect, Radius.circular(w * 0.012)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.limeLight, AppColors.limeAccent],
        ).createShader(plateRect),
    );

    // Base verde-petróleo
    final baseRect = Rect.fromLTRB(w * 0.31, h * 0.805, w * 0.69, h * 0.92);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        baseRect,
        bottomLeft: Radius.circular(w * 0.02),
        bottomRight: Radius.circular(w * 0.02),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryDarkLight, AppColors.primaryDark],
        ).createShader(baseRect),
    );

    // Plaquinha verde-amarelada no centro da base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.865),
          width: w * 0.08,
          height: h * 0.014,
        ),
        Radius.circular(h * 0.007),
      ),
      Paint()..color = AppColors.limeAccent,
    );
  }

  @override
  bool shouldRepaint(covariant TrophyPainter oldDelegate) => false;
}
