import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/process_result.dart';

class OverlayLayerConfig {
  final String imagePath;
  final double normalizedX; // Center X (0.0 to 1.0)
  final double normalizedY; // Center Y (0.0 to 1.0)
  final double normalizedWidth; // Width / CanvasWidth (0.0 to 1.0)
  final double normalizedHeight; // Height / CanvasHeight (0.0 to 1.0)
  final double rotation; // In radians
  final double opacity; // 0.0 to 1.0
  final bool hasBorder;
  final int borderColorValue;
  final double borderWidth;

  const OverlayLayerConfig({
    required this.imagePath,
    required this.normalizedX,
    required this.normalizedY,
    required this.normalizedWidth,
    required this.normalizedHeight,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.hasBorder = false,
    this.borderColorValue = 0xFFCCCCCC,
    this.borderWidth = 1.5,
  });
}

enum CanvasPageSize { matchDocument, a4Portrait, a4Landscape }

class DocumentOverlayParams {
  final String? baseImagePath; // null for blank paper
  final CanvasPageSize pageSize;
  final List<OverlayLayerConfig> layers;
  final String outputFormat; // 'jpg' or 'png'
  final int outputQuality; // 1-100, default 95

  const DocumentOverlayParams({
    this.baseImagePath,
    this.pageSize = CanvasPageSize.matchDocument,
    required this.layers,
    this.outputFormat = 'jpg',
    this.outputQuality = 95,
  });
}

class DocumentOverlayCompositor {
  DocumentOverlayCompositor._();

  /// Composites base document and all overlay layers at print resolution in a background isolate.
  static Future<ProcessResult> composite(DocumentOverlayParams params) async {
    final cacheDir = await getTemporaryDirectory();
    final outputDirPath = cacheDir.path;

    return compute(
      _compositeInternal,
      _IsolateParams(params: params, outputDirPath: outputDirPath),
    );
  }

  static Future<ProcessResult> _compositeInternal(
    _IsolateParams isolateParams,
  ) async {
    final stopwatch = Stopwatch()..start();
    final params = isolateParams.params;

    img.Image canvas;

    int origW = 2480;
    int origH = 3508;
    int origSize = 0;

    // 1. Prepare Base Canvas
    if (params.baseImagePath != null &&
        File(params.baseImagePath!).existsSync()) {
      final baseFile = File(params.baseImagePath!);
      final bytes = await baseFile.readAsBytes();
      origSize = bytes.length;
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Failed to decode base document image');
      }
      origW = decoded.width;
      origH = decoded.height;

      if (params.pageSize == CanvasPageSize.a4Portrait ||
          params.pageSize == CanvasPageSize.a4Landscape) {
        // Place base image onto A4 sheet
        final a4W = params.pageSize == CanvasPageSize.a4Portrait ? 2480 : 3508;
        final a4H = params.pageSize == CanvasPageSize.a4Portrait ? 3508 : 2480;
        canvas = img.Image(width: a4W, height: a4H, numChannels: 4);
        img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));

        // Scale document to fit comfortably on A4
        final scale = math.min((a4W * 0.9) / origW, (a4H * 0.9) / origH);
        final fitW = (origW * scale).round();
        final fitH = (origH * scale).round();
        final resizedBase = img.copyResize(
          decoded,
          width: fitW,
          height: fitH,
          interpolation: img.Interpolation.cubic,
        );
        final posX = ((a4W - fitW) / 2).round();
        final posY = ((a4H - fitH) / 2).round();
        img.compositeImage(canvas, resizedBase, dstX: posX, dstY: posY);
      } else {
        canvas = decoded;
      }
    } else {
      // Blank A4 Paper (Print Quality 300 DPI: 2480 x 3508)
      final a4W = params.pageSize == CanvasPageSize.a4Landscape ? 3508 : 2480;
      final a4H = params.pageSize == CanvasPageSize.a4Landscape ? 2480 : 3508;
      canvas = img.Image(width: a4W, height: a4H, numChannels: 4);
      img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
      origW = a4W;
      origH = a4H;
    }

    final canvasW = canvas.width;
    final canvasH = canvas.height;

    // 2. Composite Overlay Layers sequentially
    for (final layer in params.layers) {
      final layerFile = File(layer.imagePath);
      if (!layerFile.existsSync()) continue;

      final layerBytes = await layerFile.readAsBytes();
      final layerDecoded = img.decodeImage(layerBytes);
      if (layerDecoded == null) continue;

      // Calculate pixel dimensions
      int targetW = (layer.normalizedWidth * canvasW).round().clamp(
        10,
        canvasW * 2,
      );
      int targetH = (layer.normalizedHeight * canvasH).round().clamp(
        10,
        canvasH * 2,
      );

      img.Image layerWorking = img.copyResize(
        layerDecoded,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.cubic,
      );

      // Draw border if enabled (cutting guide for ID cards)
      if (layer.hasBorder) {
        final bColor = layer.borderColorValue;
        final a = (bColor >> 24) & 0xFF;
        final r = (bColor >> 16) & 0xFF;
        final g = (bColor >> 8) & 0xFF;
        final b = bColor & 0xFF;
        final borderColorObj = img.ColorRgba8(r, g, b, a);
        final stroke = layer.borderWidth.round().clamp(1, 10);

        for (int i = 0; i < stroke; i++) {
          img.drawRect(
            layerWorking,
            x1: i,
            y1: i,
            x2: layerWorking.width - 1 - i,
            y2: layerWorking.height - 1 - i,
            color: borderColorObj,
          );
        }
      }

      // Rotate if needed
      if (layer.rotation.abs() > 0.001) {
        final deg = (layer.rotation * 180.0 / math.pi) % 360;
        layerWorking = img.copyRotate(
          layerWorking,
          angle: deg,
          interpolation: img.Interpolation.linear,
        );
      }

      // Calculate top-left placement from center coordinates
      final centerX = (layer.normalizedX * canvasW).round();
      final centerY = (layer.normalizedY * canvasH).round();
      final dstX = centerX - (layerWorking.width / 2).round();
      final dstY = centerY - (layerWorking.height / 2).round();

      // Composite with alpha blending
      img.compositeImage(canvas, layerWorking, dstX: dstX, dstY: dstY);
    }

    // 3. Encode to desired output format
    Uint8List outputBytes;
    final format = params.outputFormat.toLowerCase();
    if (format == 'png') {
      outputBytes = Uint8List.fromList(img.encodePng(canvas));
    } else {
      outputBytes = Uint8List.fromList(
        img.encodeJpg(canvas, quality: params.outputQuality.clamp(50, 100)),
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = format == 'png' ? 'png' : 'jpg';
    final outputFilePath = p.join(
      isolateParams.outputDirPath,
      'doc_overlay_$timestamp.$extension',
    );
    final outFile = File(outputFilePath);
    await outFile.writeAsBytes(outputBytes, flush: true);

    stopwatch.stop();

    return ProcessResult(
      originalPath: params.baseImagePath ?? outputFilePath,
      outputPath: outputFilePath,
      originalSizeBytes: origSize > 0 ? origSize : outputBytes.length,
      outputSizeBytes: outputBytes.length,
      originalWidth: origW,
      originalHeight: origH,
      outputWidth: canvas.width,
      outputHeight: canvas.height,
      outputFormat: extension,
      finalQuality: params.outputQuality,
      processingTime: stopwatch.elapsed,
    );
  }
}

class _IsolateParams {
  final DocumentOverlayParams params;
  final String outputDirPath;

  const _IsolateParams({required this.params, required this.outputDirPath});
}
