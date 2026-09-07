import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/file_size_extension.dart';
import '../../../data/models/process_result.dart';
import '../../../services/share_service.dart';

class FullscreenImagePreview extends StatefulWidget {
  final ProcessResult result;
  final bool initialShowOriginal;
  final String heroTag;

  const FullscreenImagePreview({
    super.key,
    required this.result,
    this.initialShowOriginal = false,
    this.heroTag = 'result_image_preview',
  });

  @override
  State<FullscreenImagePreview> createState() => _FullscreenImagePreviewState();
}

class _FullscreenImagePreviewState extends State<FullscreenImagePreview> {
  late bool _showOriginal;
  late final TransformationController _transformationController;
  bool _isZoomedIn = false;

  @override
  void initState() {
    super.initState();
    _showOriginal = widget.initialShowOriginal;
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final isZoomed = !_transformationController.value.isIdentity();
    if (isZoomed != _isZoomedIn) {
      setState(() => _isZoomedIn = isZoomed);
    }
  }

  void _handleDoubleTap() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isZoomedIn) {
        _transformationController.value = Matrix4.identity();
      } else {
        _transformationController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
      }
    });
  }

  void _resetZoom() {
    HapticFeedback.lightImpact();
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  void _handleShare(String path) {
    HapticFeedback.selectionClick();
    ShareService.shareImage(
      path,
      text: 'Resized with Image Tools',
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final currentPath = _showOriginal ? result.originalPath : result.outputPath;
    final currentFile = File(currentPath);
    final currentWidth = _showOriginal ? result.originalWidth : result.outputWidth;
    final currentHeight = _showOriginal ? result.originalHeight : result.outputHeight;
    final currentSize = _showOriginal ? result.originalSizeBytes : result.outputSizeBytes;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _showOriginal ? 'Original Image' : 'Optimized Image',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '$currentWidth × $currentHeight px • ${currentSize.toReadableFileSize()} • ${result.outputFormat.toUpperCase()}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: 'Share',
            onPressed: () => _handleShare(currentPath),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Zoomable Image
          GestureDetector(
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 8.0,
              clipBehavior: Clip.none,
              child: Center(
                child: currentFile.existsSync()
                    ? Hero(
                        tag: widget.heroTag,
                        child: Image.file(
                          currentFile,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Icon(Icons.broken_image, size: 64, color: Colors.white54),
              ),
            ),
          ),

          // Floating Reset Zoom Button (when zoomed in)
          if (_isZoomedIn)
            Positioned(
              top: 16,
              right: 16,
              child: Material(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _resetZoom,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restart_alt_rounded, size: 15, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Reset Zoom',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Controls Overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle between Optimized and Original
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Optimized Tab
                      _ToggleTab(
                        label: 'Optimized',
                        subtitle: result.outputSizeBytes.toReadableFileSize(),
                        isSelected: !_showOriginal,
                        accentColor: AppColors.success,
                        onTap: () {
                          if (_showOriginal) {
                            HapticFeedback.selectionClick();
                            setState(() => _showOriginal = false);
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      // Original Tab
                      _ToggleTab(
                        label: 'Original',
                        subtitle: result.originalSizeBytes.toReadableFileSize(),
                        isSelected: _showOriginal,
                        accentColor: AppColors.primary,
                        onTap: () {
                          if (!_showOriginal) {
                            HapticFeedback.selectionClick();
                            setState(() => _showOriginal = true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Pinch / Double-tap hint
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pinch_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Pinch or double-tap to zoom',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? accentColor.withValues(alpha: 0.25) : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: isSelected
                ? Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.2)
                : Border.all(color: Colors.transparent, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(Icons.check_circle_rounded, size: 14, color: accentColor),
                const SizedBox(width: 6),
              ],
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.white60,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? accentColor : Colors.white38,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
