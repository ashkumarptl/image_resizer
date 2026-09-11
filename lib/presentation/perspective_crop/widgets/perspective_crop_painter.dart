import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/image_service/perspective_cropper.dart';

enum ActiveCorner {
  none,
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
}

class PerspectiveCropPainter extends CustomPainter {
  final Rect imageRect;
  final NormalizedPoint topLeft;
  final NormalizedPoint topRight;
  final NormalizedPoint bottomRight;
  final NormalizedPoint bottomLeft;
  final ActiveCorner activeCorner;
  final bool isDark;

  PerspectiveCropPainter({
    required this.imageRect,
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    required this.activeCorner,
    required this.isDark,
  });

  Offset _toCanvasOffset(NormalizedPoint p) {
    return Offset(
      imageRect.left + p.x * imageRect.width,
      imageRect.top + p.y * imageRect.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tl = _toCanvasOffset(topLeft);
    final tr = _toCanvasOffset(topRight);
    final br = _toCanvasOffset(bottomRight);
    final bl = _toCanvasOffset(bottomLeft);

    // 1. Draw darkened scrim outside the quadrilateral
    final fullRectPath = Path()..addRect(imageRect);
    final quadPath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    final scrimPath = Path.combine(PathOperation.difference, fullRectPath, quadPath);
    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawPath(scrimPath, scrimPaint);

    // 2. Draw interior rule-of-thirds grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 2; i++) {
      final t = i / 3.0;
      // Vertical grid lines (interpolate Top <-> Bottom)
      final topPt = Offset.lerp(tl, tr, t)!;
      final botPt = Offset.lerp(bl, br, t)!;
      canvas.drawLine(topPt, botPt, gridPaint);

      // Horizontal grid lines (interpolate Left <-> Right)
      final leftPt = Offset.lerp(tl, bl, t)!;
      final rightPt = Offset.lerp(tr, br, t)!;
      canvas.drawLine(leftPt, rightPt, gridPaint);
    }

    // 3. Draw quadrilateral border lines
    final borderGlowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.4)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(quadPath, borderGlowPaint);

    final borderLinePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(quadPath, borderLinePaint);

    // 4. Draw corner handles
    _drawCornerHandle(canvas, tl, activeCorner == ActiveCorner.topLeft);
    _drawCornerHandle(canvas, tr, activeCorner == ActiveCorner.topRight);
    _drawCornerHandle(canvas, br, activeCorner == ActiveCorner.bottomRight);
    _drawCornerHandle(canvas, bl, activeCorner == ActiveCorner.bottomLeft);
  }

  void _drawCornerHandle(Canvas canvas, Offset position, bool isActive) {
    final outerRadius = isActive ? 18.0 : 13.0;
    final innerRadius = isActive ? 5.5 : 4.0;

    // Active outer pulse halo
    if (isActive) {
      final haloPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(position, outerRadius + 8.0, haloPaint);
    }

    // Handle background / shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(position.translate(0, 1.5), outerRadius, shadowPaint);

    // Handle outer ring
    final outerPaint = Paint()
      ..color = isActive ? AppColors.primary : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, outerRadius, outerPaint);

    final strokePaint = Paint()
      ..color = isActive ? Colors.white : AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(position, outerRadius, strokePaint);

    // Handle inner dot
    final innerPaint = Paint()
      ..color = isActive ? Colors.white : AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, innerRadius, innerPaint);
  }

  @override
  bool shouldRepaint(covariant PerspectiveCropPainter oldDelegate) {
    return oldDelegate.imageRect != imageRect ||
        oldDelegate.topLeft != topLeft ||
        oldDelegate.topRight != topRight ||
        oldDelegate.bottomRight != bottomRight ||
        oldDelegate.bottomLeft != bottomLeft ||
        oldDelegate.activeCorner != activeCorner ||
        oldDelegate.isDark != isDark;
  }
}
