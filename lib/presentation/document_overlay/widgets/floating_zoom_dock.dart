import 'package:flutter/material.dart';

/// Floating zoom indicators and buttons (scale pill, zoom in, zoom out, reset).
class FloatingZoomDock extends StatelessWidget {
  final TransformationController transformationController;
  final VoidCallback onResetZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final bool isDark;

  const FloatingZoomDock({
    super.key,
    required this.transformationController,
    required this.onResetZoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top-Left: Zoom percentage pill or Reset button
        Positioned(
          top: 12,
          left: 12,
          child: ValueListenableBuilder<Matrix4>(
            valueListenable: transformationController,
            builder: (context, matrix, _) {
              final scale = matrix.getMaxScaleOnAxis();
              final isZoomed = (scale - 1.0).abs() > 0.05;
              final percentText = '${(scale * 100).round()}%';

              if (isZoomed) {
                return Material(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: onResetZoom,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.zoom_out_map_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$percentText • Reset',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pinch_rounded,
                        size: 13,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$percentText • Pinch or double-tap',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Top-Right: Quick Zoom In / Out / Reset buttons
        Positioned(
          top: 12,
          right: 12,
          child: ValueListenableBuilder<Matrix4>(
            valueListenable: transformationController,
            builder: (context, matrix, _) {
              final scale = matrix.getMaxScaleOnAxis();
              final isZoomed = (scale - 1.0).abs() > 0.05;

              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Zoom in',
                      onPressed: onZoomIn,
                    ),
                    Container(
                      width: 20,
                      height: 1,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    _buildIconButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Zoom out',
                      onPressed: onZoomOut,
                    ),
                    if (isZoomed) ...[
                      Container(
                        width: 20,
                        height: 1,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      _buildIconButton(
                        icon: Icons.restart_alt_rounded,
                        tooltip: 'Reset zoom (100%)',
                        onPressed: onResetZoom,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}
