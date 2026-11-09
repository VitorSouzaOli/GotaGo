import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

// Anel de progresso da Home: trilho claro + arco teal a partir do topo
class HydrationRingPainter extends CustomPainter {
  // 0 a 1 (fração da meta diária)
  final double progress;
  final double strokeWidth;

  HydrationRingPainter({required this.progress, this.strokeWidth = 18});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.ringTrack
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final sweep = 2 * pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      Paint()
        ..color = AppColors.dropDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant HydrationRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
