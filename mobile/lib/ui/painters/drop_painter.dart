import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class DropPainter extends CustomPainter {
  // 0 = gota clara (surgindo na splash), 1 = cor final
  final double colorProgress;

  const DropPainter({this.colorProgress = 1});

  @override
  void paint(Canvas canvas, Size size) {
    paintDrop(canvas, Offset.zero & size, colorProgress: colorProgress);
  }

  @override
  bool shouldRepaint(covariant DropPainter oldDelegate) {
    return oldDelegate.colorProgress != colorProgress;
  }
}

// Contorno da gota: ponta fina no topo e base arredondada.
// Fica separado para o troféu reaproveitar o mesmo formato.
Path dropPath(Rect rect) {
  double x(double f) => rect.left + rect.width * f;
  double y(double f) => rect.top + rect.height * f;

  return Path()
    ..moveTo(x(0.5), y(0))
    ..cubicTo(x(0.56), y(0.14), x(1.0), y(0.40), x(1.0), y(0.68))
    ..cubicTo(x(1.0), y(0.87), x(0.77), y(1.0), x(0.5), y(1.0))
    ..cubicTo(x(0.23), y(1.0), x(0), y(0.87), x(0), y(0.68))
    ..cubicTo(x(0), y(0.40), x(0.44), y(0.14), x(0.5), y(0))
    ..close();
}

void paintDrop(Canvas canvas, Rect rect, {double colorProgress = 1}) {
  double x(double f) => rect.left + rect.width * f;
  double y(double f) => rect.top + rect.height * f;

  final topColor = Color.lerp(
    AppColors.dropLightPale,
    AppColors.dropLight,
    colorProgress,
  )!;
  final bottomColor = Color.lerp(
    AppColors.dropDarkPale,
    AppColors.dropDark,
    colorProgress,
  )!;

  final fillPaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [topColor, bottomColor],
    ).createShader(rect);

  canvas.drawPath(dropPath(rect), fillPaint);

  // Brilho: risco fino e curvo no lado esquerdo
  final highlightPath = Path()
    ..moveTo(x(0.31), y(0.38))
    ..quadraticBezierTo(x(0.13), y(0.52), x(0.15), y(0.71))
    ..quadraticBezierTo(x(0.21), y(0.53), x(0.31), y(0.38))
    ..close();

  canvas.drawPath(
    highlightPath,
    Paint()..color = Colors.white.withValues(alpha: 0.6),
  );
}
