import 'package:flutter/material.dart';

/// Paints subtle margin guidelines representing printable areas on the A4 canvas.
class CanvasGridPainter extends CustomPainter {
  const CanvasGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final marginPaint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final margin = size.width * 0.05;
    canvas.drawRect(
      Rect.fromLTWH(
        margin,
        margin,
        size.width - (margin * 2),
        size.height - (margin * 2),
      ),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
