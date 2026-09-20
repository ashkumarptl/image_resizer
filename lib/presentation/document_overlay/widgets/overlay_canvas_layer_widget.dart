import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../models/overlay_item_model.dart';

/// Interactive canvas layer widget providing gestures for move, corner scale,
/// rotation, duplication, and deletion.
class OverlayCanvasLayerWidget extends StatelessWidget {
  final OverlayItemModel layer;
  final bool isSelected;
  final double canvasWidth;
  final double canvasHeight;
  final double currentCanvasRatio;
  final bool isDark;
  final VoidCallback onTap;
  final void Function(double dx, double dy) onMove;
  final VoidCallback onMoveEnd;
  final void Function(double newW, double newH, double newX, double newY)
  onResize;
  final VoidCallback onResizeEnd;
  final void Function(double newRotation) onRotate;
  final VoidCallback onRotateEnd;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final void Function(bool isDragging) onDragStateChanged;

  const OverlayCanvasLayerWidget({
    super.key,
    required this.layer,
    required this.isSelected,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.currentCanvasRatio,
    required this.isDark,
    required this.onTap,
    required this.onMove,
    required this.onMoveEnd,
    required this.onResize,
    required this.onResizeEnd,
    required this.onRotate,
    required this.onRotateEnd,
    required this.onDelete,
    required this.onDuplicate,
    required this.onDragStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final layerW = layer.normalizedWidth * canvasWidth;
    final layerH = layer.normalizedHeight * canvasHeight;

    const handleMargin = 32.0;
    final activeMargin = isSelected ? handleMargin : 0.0;

    final posX =
        (layer.normalizedX * canvasWidth) - (layerW / 2) - activeMargin;
    final posY =
        (layer.normalizedY * canvasHeight) - (layerH / 2) - activeMargin;
    final totalW = layerW + (activeMargin * 2);
    final totalH = layerH + (activeMargin * 2);

    return Positioned(
      left: posX,
      top: posY,
      width: totalW,
      height: totalH,
      child: Transform.rotate(
        angle: layer.rotation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Central Image Content & Move Pan Detector
            Positioned(
              left: activeMargin,
              top: activeMargin,
              width: layerW,
              height: layerH,
              child: Listener(
                onPointerDown: (_) => onDragStateChanged(true),
                onPointerUp: (_) => onDragStateChanged(false),
                onPointerCancel: (_) => onDragStateChanged(false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
                  onPanStart: (_) => onDragStateChanged(true),
                  onPanUpdate: (details) {
                    final dx = details.delta.dx / canvasWidth;
                    final dy = details.delta.dy / canvasHeight;
                    onMove(dx, dy);
                  },
                  onPanEnd: (_) {
                    onDragStateChanged(false);
                    onMoveEnd();
                  },
                  onPanCancel: () => onDragStateChanged(false),
                  child: Opacity(
                    opacity: layer.opacity,
                    child: Container(
                      decoration: BoxDecoration(
                        border: isSelected
                            ? Border.all(color: AppColors.primary, width: 2)
                            : (layer.hasBorder
                                  ? Border.all(
                                      color: layer.borderColor,
                                      width: layer.borderWidth,
                                    )
                                  : null),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.file(
                        layer.file,
                        fit: BoxFit.fill,
                        cacheWidth: 1000,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. Selection Handles (Only when layer is selected)
            if (isSelected) ...[
              // Bottom-Right: Corner Scale Handle (Large 44x44 touch area)
              Positioned(
                left: activeMargin + layerW - 22,
                top: activeMargin + layerH - 22,
                width: 44,
                height: 44,
                child: Listener(
                  onPointerDown: (_) => onDragStateChanged(true),
                  onPointerUp: (_) => onDragStateChanged(false),
                  onPointerCancel: (_) => onDragStateChanged(false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => onDragStateChanged(true),
                    onPanUpdate: (details) {
                      // Project delta into layer's rotated coordinate space
                      double dx = details.delta.dx;
                      double dy = details.delta.dy;
                      if (layer.rotation.abs() > 0.01) {
                        final cosA = math.cos(-layer.rotation);
                        final sinA = math.sin(-layer.rotation);
                        final rotX = (dx * cosA) - (dy * sinA);
                        final rotY = (dx * sinA) + (dy * cosA);
                        dx = rotX;
                        dy = rotY;
                      }

                      final deltaPx = (dx.abs() > dy.abs()) ? dx : dy;
                      final deltaNorm = deltaPx / canvasWidth;

                      final newW = (layer.normalizedWidth + deltaNorm).clamp(
                        0.08,
                        0.95,
                      );
                      final newH =
                          (newW * (currentCanvasRatio / layer.aspectRatio))
                              .clamp(0.03, 0.95);

                      // Anchor top-left corner
                      final dW = newW - layer.normalizedWidth;
                      final dH = newH - layer.normalizedHeight;
                      final newX = (layer.normalizedX + (dW / 2)).clamp(
                        0.05,
                        0.95,
                      );
                      final newY = (layer.normalizedY + (dH / 2)).clamp(
                        0.05,
                        0.95,
                      );

                      onResize(newW, newH, newX, newY);
                    },
                    onPanEnd: (_) {
                      onDragStateChanged(false);
                      onResizeEnd();
                    },
                    onPanCancel: () => onDragStateChanged(false),
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Top-Right: Delete Handle (Large 44x44 touch area)
              Positioned(
                left: activeMargin + layerW - 22,
                top: activeMargin - 22,
                width: 44,
                height: 44,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),

              // Top-Left: Duplicate Handle (Large 44x44 touch area)
              Positioned(
                left: activeMargin - 22,
                top: activeMargin - 22,
                width: 44,
                height: 44,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDuplicate,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ),

              // Top-Center: Rotate Handle (Large 44x44 touch area)
              Positioned(
                left: activeMargin + (layerW / 2) - 22,
                top: activeMargin - 30,
                width: 44,
                height: 44,
                child: Listener(
                  onPointerDown: (_) => onDragStateChanged(true),
                  onPointerUp: (_) => onDragStateChanged(false),
                  onPointerCancel: (_) => onDragStateChanged(false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => onDragStateChanged(true),
                    onPanUpdate: (details) {
                      final nextRot =
                          layer.rotation + (details.delta.dx * 0.03);
                      onRotate(nextRot);
                    },
                    onPanEnd: (_) {
                      onDragStateChanged(false);
                      onRotateEnd();
                    },
                    onPanCancel: () => onDragStateChanged(false),
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.rotate_right_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
