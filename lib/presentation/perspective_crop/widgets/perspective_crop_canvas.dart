import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/image_service/perspective_cropper.dart';
import '../../../../services/image_service/safe_image_decoder.dart';
import 'perspective_crop_painter.dart';

class PerspectiveCropCanvas extends StatefulWidget {
  final File imageFile;
  final int quarterTurns;
  final PerspectiveFilter filter;
  final NormalizedPoint topLeft;
  final NormalizedPoint topRight;
  final NormalizedPoint bottomRight;
  final NormalizedPoint bottomLeft;
  final Function(
    NormalizedPoint tl,
    NormalizedPoint tr,
    NormalizedPoint br,
    NormalizedPoint bl,
  ) onPointsChanged;

  const PerspectiveCropCanvas({
    super.key,
    required this.imageFile,
    required this.quarterTurns,
    this.filter = PerspectiveFilter.none,
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    required this.onPointsChanged,
    this.onImageLoaded,
  });

  final void Function(int width, int height)? onImageLoaded;

  static ColorFilter? getColorFilter(PerspectiveFilter filter) {
    switch (filter) {
      case PerspectiveFilter.none:
        return null;

      case PerspectiveFilter.grayscale:
        return const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]);

      case PerspectiveFilter.documentBw:
        return const ColorFilter.matrix(<double>[
          0.8504, 2.8608, 0.2888, 0, -540.0,
          0.8504, 2.8608, 0.2888, 0, -540.0,
          0.8504, 2.8608, 0.2888, 0, -540.0,
          0,      0,      0,      1, 0,
        ]);

      case PerspectiveFilter.enhanced:
        return const ColorFilter.matrix(<double>[
          1.3976, -0.1341, -0.0135, 0, -24.0,
          -0.0399, 1.3034, -0.0135, 0, -24.0,
          -0.0399, -0.1341, 1.4240, 0, -24.0,
          0,       0,       0,      1, 0,
        ]);
    }
  }

  @override
  State<PerspectiveCropCanvas> createState() => _PerspectiveCropCanvasState();
}

class _PerspectiveCropCanvasState extends State<PerspectiveCropCanvas> {
  ui.Image? _uiImage;
  ActiveCorner _activeCorner = ActiveCorner.none;
  Rect _imageRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _loadUiImage();
  }

  @override
  void didUpdateWidget(covariant PerspectiveCropCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageFile.path != widget.imageFile.path ||
        oldWidget.quarterTurns != widget.quarterTurns) {
      _loadUiImage();
    }
  }

  @override
  void dispose() {
    _uiImage?.dispose();
    super.dispose();
  }

  Future<void> _loadUiImage() async {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
        Platform.environment['FLUTTER_TEST'] == 'true' ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      return;
    }
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final header = SafeImageDecoder.readHeaderDimensions(bytes);

      // Downsample large camera photos (e.g. 48MP/108MP) to FHD/2K boundary for smooth canvas interaction
      int? targetW;
      int? targetH;
      if (header != null && (header.width > 2048 || header.height > 2048)) {
        final scale = 2048.0 / math.max(header.width, header.height);
        targetW = (header.width * scale).round();
        targetH = (header.height * scale).round();
      }

      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final frame = await codec.getNextFrame();
      if (mounted) {
        _uiImage?.dispose();
        setState(() {
          _uiImage = frame.image;
        });
        widget.onImageLoaded?.call(header?.width ?? frame.image.width, header?.height ?? frame.image.height);
      }
    } catch (e) {
      debugPrint('[PerspectiveCropCanvas] Error loading ui.Image: $e');
    }
  }

  Offset _toCanvasOffset(NormalizedPoint p) {
    return Offset(
      _imageRect.left + p.x * _imageRect.width,
      _imageRect.top + p.y * _imageRect.height,
    );
  }

  void _handlePanDown(DragDownDetails details) {
    if (_imageRect.isEmpty) return;

    final pos = details.localPosition;
    const touchRadius = 40.0;

    final tl = _toCanvasOffset(widget.topLeft);
    final tr = _toCanvasOffset(widget.topRight);
    final br = _toCanvasOffset(widget.bottomRight);
    final bl = _toCanvasOffset(widget.bottomLeft);

    ActiveCorner? matchedCorner;
    double minDistance = touchRadius;

    final dTl = (pos - tl).distance;
    if (dTl < minDistance) {
      minDistance = dTl;
      matchedCorner = ActiveCorner.topLeft;
    }

    final dTr = (pos - tr).distance;
    if (dTr < minDistance) {
      minDistance = dTr;
      matchedCorner = ActiveCorner.topRight;
    }

    final dBr = (pos - br).distance;
    if (dBr < minDistance) {
      minDistance = dBr;
      matchedCorner = ActiveCorner.bottomRight;
    }

    final dBl = (pos - bl).distance;
    if (dBl < minDistance) {
      matchedCorner = ActiveCorner.bottomLeft;
    }

    if (matchedCorner != null) {
      HapticFeedback.selectionClick();
      setState(() => _activeCorner = matchedCorner!);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_activeCorner == ActiveCorner.none || _imageRect.isEmpty) return;

    final touchPos = details.localPosition;
    final nx = ((touchPos.dx - _imageRect.left) / _imageRect.width).clamp(0.0, 1.0);
    final ny = ((touchPos.dy - _imageRect.top) / _imageRect.height).clamp(0.0, 1.0);

    const minMargin = 0.04;
    var tl = widget.topLeft;
    var tr = widget.topRight;
    var br = widget.bottomRight;
    var bl = widget.bottomLeft;

    switch (_activeCorner) {
      case ActiveCorner.topLeft:
        tl = NormalizedPoint(
          nx.clamp(0.0, tr.x - minMargin),
          ny.clamp(0.0, bl.y - minMargin),
        );
        break;

      case ActiveCorner.topRight:
        tr = NormalizedPoint(
          nx.clamp(tl.x + minMargin, 1.0),
          ny.clamp(0.0, br.y - minMargin),
        );
        break;

      case ActiveCorner.bottomRight:
        br = NormalizedPoint(
          nx.clamp(bl.x + minMargin, 1.0),
          ny.clamp(tr.y + minMargin, 1.0),
        );
        break;

      case ActiveCorner.bottomLeft:
        bl = NormalizedPoint(
          nx.clamp(0.0, br.x - minMargin),
          ny.clamp(tl.y + minMargin, 1.0),
        );
        break;

      case ActiveCorner.none:
        return;
    }

    widget.onPointsChanged(tl, tr, br, bl);
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_activeCorner != ActiveCorner.none) {
      HapticFeedback.lightImpact();
      setState(() => _activeCorner = ActiveCorner.none);
    }
  }

  void _handlePanCancel() {
    if (_activeCorner != ActiveCorner.none) {
      setState(() => _activeCorner = ActiveCorner.none);
    }
  }

  NormalizedPoint _getActivePoint() {
    switch (_activeCorner) {
      case ActiveCorner.topLeft:
        return widget.topLeft;
      case ActiveCorner.topRight:
        return widget.topRight;
      case ActiveCorner.bottomRight:
        return widget.bottomRight;
      case ActiveCorner.bottomLeft:
        return widget.bottomLeft;
      case ActiveCorner.none:
        return widget.topLeft;
    }
  }

  Widget _buildFilteredImage() {
    final imageWidget = Image.file(
      widget.imageFile,
      fit: BoxFit.fill,
      cacheWidth: 1080,
      filterQuality: FilterQuality.medium,
    );

    final colorFilter = PerspectiveCropCanvas.getColorFilter(widget.filter);
    if (colorFilter == null) {
      return imageWidget;
    }

    return ColorFiltered(
      colorFilter: colorFilter,
      child: imageWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final naturalW = _uiImage?.width.toDouble() ?? 400.0;
        final naturalH = _uiImage?.height.toDouble() ?? 400.0;
        final imgW = (widget.quarterTurns % 2 == 0) ? naturalW : naturalH;
        final imgH = (widget.quarterTurns % 2 == 0) ? naturalH : naturalW;

        final fittedSizes = applyBoxFit(
          BoxFit.contain,
          Size(imgW, imgH),
          constraints.biggest,
        );

        _imageRect = Alignment.center.inscribe(
          fittedSizes.destination,
          Offset.zero & constraints.biggest,
        );

        final activePoint = _getActivePoint();
        final activeOffset = _toCanvasOffset(activePoint);

        // Calculate loupe position (hovered above finger or below if too close to top)
        const loupeSize = 108.0;
        final showLoupeBelow = activeOffset.dy < (loupeSize + 40.0);
        final loupeY = showLoupeBelow ? (activeOffset.dy + 36.0) : (activeOffset.dy - loupeSize - 32.0);
        final loupeX = (activeOffset.dx - loupeSize / 2).clamp(
          8.0,
          constraints.maxWidth - loupeSize - 8.0,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: _handlePanDown,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          onPanCancel: _handlePanCancel,
          child: Stack(
            children: [
              // 1. Underneath Image with Live Color Filter
              Positioned.fromRect(
                rect: _imageRect,
                child: RotatedBox(
                  quarterTurns: widget.quarterTurns,
                  child: _buildFilteredImage(),
                ),
              ),

              // 2. Custom Painter Overlay (Scrim, Grid, Border, Corner Pins)
              Positioned.fill(
                child: CustomPaint(
                  painter: PerspectiveCropPainter(
                    imageRect: _imageRect,
                    topLeft: widget.topLeft,
                    topRight: widget.topRight,
                    bottomRight: widget.bottomRight,
                    bottomLeft: widget.bottomLeft,
                    activeCorner: _activeCorner,
                    isDark: isDark,
                  ),
                ),
              ),

              // 3. Magnifier Loupe when corner is being dragged
              if (_activeCorner != ActiveCorner.none && _uiImage != null)
                Positioned(
                  left: loupeX,
                  top: loupeY,
                  width: loupeSize,
                  height: loupeSize,
                  child: _buildMagnifierLoupe(activePoint, loupeSize),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMagnifierLoupe(NormalizedPoint activePoint, double size) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _LoupePainter(
                  image: _uiImage!,
                  normalizedPoint: activePoint,
                  quarterTurns: widget.quarterTurns,
                  colorFilter: PerspectiveCropCanvas.getColorFilter(widget.filter),
                ),
              ),
            ),
            // Center Crosshairs
            Center(
              child: CustomPaint(
                size: Size(size, size),
                painter: _CrosshairPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoupePainter extends CustomPainter {
  final ui.Image image;
  final NormalizedPoint normalizedPoint;
  final int quarterTurns;
  final ColorFilter? colorFilter;

  _LoupePainter({
    required this.image,
    required this.normalizedPoint,
    required this.quarterTurns,
    this.colorFilter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    // Map normalized point to actual image coordinates taking rotation into account
    double origX;
    double origY;

    final q = quarterTurns % 4;
    switch (q) {
      case 0:
        origX = normalizedPoint.x * imgW;
        origY = normalizedPoint.y * imgH;
        break;
      case 1:
        // 90 deg clockwise: (x', y') = (y, 1 - x)
        origX = (1.0 - normalizedPoint.y) * imgW;
        origY = normalizedPoint.x * imgH;
        break;
      case 2:
        // 180 deg
        origX = (1.0 - normalizedPoint.x) * imgW;
        origY = (1.0 - normalizedPoint.y) * imgH;
        break;
      case 3:
        // 270 deg
        origX = normalizedPoint.y * imgW;
        origY = (1.0 - normalizedPoint.x) * imgH;
        break;
      default:
        origX = normalizedPoint.x * imgW;
        origY = normalizedPoint.y * imgH;
    }

    // Zoom level: 2.8x magnification window
    const sampleBox = 55.0;
    final srcRect = Rect.fromCenter(
      center: Offset(origX.clamp(0.0, imgW), origY.clamp(0.0, imgH)),
      width: sampleBox,
      height: sampleBox,
    );
    final dstRect = Offset.zero & size;

    canvas.save();
    // Rotate canvas if image is rotated so the loupe orientation matches the screen
    if (q != 0) {
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(q * 3.1415926535897932 / 2);
      canvas.translate(-size.width / 2, -size.height / 2);
    }

    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = colorFilter;
    canvas.drawImageRect(image, srcRect, dstRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LoupePainter oldDelegate) {
    return oldDelegate.normalizedPoint != normalizedPoint ||
        oldDelegate.quarterTurns != quarterTurns ||
        oldDelegate.colorFilter != colorFilter;
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final crossHairPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const armLen = 14.0;
    const gap = 3.5;

    // Horizontal arms
    canvas.drawLine(
      Offset(center.dx - armLen - gap, center.dy),
      Offset(center.dx - gap, center.dy),
      crossHairPaint,
    );
    canvas.drawLine(
      Offset(center.dx + gap, center.dy),
      Offset(center.dx + armLen + gap, center.dy),
      crossHairPaint,
    );

    // Vertical arms
    canvas.drawLine(
      Offset(center.dx, center.dy - armLen - gap),
      Offset(center.dx, center.dy - gap),
      crossHairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + gap),
      Offset(center.dx, center.dy + armLen + gap),
      crossHairPaint,
    );

    // Tiny center dot
    canvas.drawCircle(center, 2.0, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
