import 'package:flutter/material.dart';

// Linha horizontal tracejada (meta diária no gráfico do Histórico)
class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double gap;

  const DashedLinePainter({
    required this.color,
    this.dashWidth = 4,
    this.gap = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final y = size.height / 2;
    for (double x = 0; x < size.width; x += dashWidth + gap) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.gap != gap;
  }
}
