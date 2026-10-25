import 'dart:math';

import 'package:flutter/material.dart';

// "G" colorido do botão "Continuar com o Google"
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final stroke = side * 0.2;
    final center = size.center(Offset.zero);
    final radius = (side - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    double rad(double degrees) => degrees * pi / 180;

    // Arcos no sentido horário, a partir da direita (0°)
    canvas.drawArc(rect, rad(0), rad(45), false, arcPaint(_blue));
    canvas.drawArc(rect, rad(45), rad(105), false, arcPaint(_green));
    canvas.drawArc(rect, rad(150), rad(60), false, arcPaint(_yellow));
    canvas.drawArc(rect, rad(210), rad(110), false, arcPaint(_red));

    // Barra horizontal do "G"
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - stroke / 2,
        center.dx + radius + stroke / 2,
        center.dy + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant GoogleLogoPainter oldDelegate) => false;
}
