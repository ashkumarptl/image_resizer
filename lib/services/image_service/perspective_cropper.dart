import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/process_result.dart';
import 'safe_image_decoder.dart';

/// Supported aspect ratio presets for perspective rectification
enum PerspectiveCropPreset {
  auto('Auto / Natural', 'Preserve deskewed quad proportions'),
  a4('A4 Document', 'Standard 1 : 1.414 document ratio'),
  idCard('ID Card', 'Standard 85.6 : 54 mm card ratio'),
  square('1:1 Square', 'Square ratio'),
  photo4x3('4:3 Standard', '4:3 camera photo ratio'),
  photo16x9('16:9 Wide', '16:9 widescreen ratio');

  final String label;
  final String subtitle;
  const PerspectiveCropPreset(this.label, this.subtitle);
}

/// Enhancement filters applied during perspective rectification
enum PerspectiveFilter {
  none('Original', 'Preserve natural colors'),
  vividLight('Vivid Light', 'Brightened clean scan with vivid legibility'),
  contrastBw('Contrast B&W', 'High-contrast clean photocopy binarization'),
  enhanced('Vibrant', 'Enhanced contrast and clarity'),
  documentBw('Doc B&W', 'Clean document scan'),
  grayscale('Grayscale', 'Smooth monochrome tone');

  final String label;
  final String description;
  const PerspectiveFilter(this.label, this.description);
}

/// Normalized 2D point (coordinates in 0.0 to 1.0 range)
class NormalizedPoint {
  final double x;
  final double y;

  const NormalizedPoint(this.x, this.y);

  NormalizedPoint copyWith({double? x, double? y}) =>
      NormalizedPoint(x ?? this.x, y ?? this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedPoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'NormalizedPoint($x, $y)';
}

/// Options for perspective rectification
class PerspectiveCropOptions {
  final String sourcePath;
  final NormalizedPoint topLeft;
  final NormalizedPoint topRight;
  final NormalizedPoint bottomRight;
  final NormalizedPoint bottomLeft;
  final PerspectiveCropPreset preset;
  final PerspectiveFilter filter;
  final int quarterTurns;
  final int quality;
  final String outputFormat;

  const PerspectiveCropOptions({
    required this.sourcePath,
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    this.preset = PerspectiveCropPreset.auto,
    this.filter = PerspectiveFilter.none,
    this.quarterTurns = 0,
    this.quality = 90,
    this.outputFormat = 'jpg',
  });

  PerspectiveCropOptions copyWith({
    String? sourcePath,
    NormalizedPoint? topLeft,
    NormalizedPoint? topRight,
    NormalizedPoint? bottomRight,
    NormalizedPoint? bottomLeft,
    PerspectiveCropPreset? preset,
    PerspectiveFilter? filter,
    int? quarterTurns,
    int? quality,
    String? outputFormat,
  }) {
    return PerspectiveCropOptions(
      sourcePath: sourcePath ?? this.sourcePath,
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomRight: bottomRight ?? this.bottomRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
      preset: preset ?? this.preset,
      filter: filter ?? this.filter,
      quarterTurns: quarterTurns ?? this.quarterTurns,
      quality: quality ?? this.quality,
      outputFormat: outputFormat ?? this.outputFormat,
    );
  }
}

class PerspectiveCropper {
  PerspectiveCropper._();

  /// Rectifies image using perspective transformation in a background isolate
  static Future<ProcessResult> rectifyImage(PerspectiveCropOptions options) async {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
        Platform.environment['FLUTTER_TEST'] == 'true' ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    String outputDirPath;
    if (isTest) {
      outputDirPath = Directory.systemTemp.path;
    } else {
      try {
        final tempDir = await getTemporaryDirectory();
        outputDirPath = tempDir.path;
      } catch (_) {
        outputDirPath = Directory.systemTemp.path;
      }
    }

    final params = _PerspectiveIsolateParams(
      options: options,
      outputDirPath: outputDirPath,
    );

    // In test environment, execute directly to avoid compute()/Isolate blocking in widget tests
    if (isTest) {
      return _rectifyInternal(params);
    }

    return compute(
      _rectifyInternal,
      params,
    );
  }

  static Future<ProcessResult> _rectifyInternal(_PerspectiveIsolateParams params) async {
    final stopwatch = Stopwatch()..start();
    final options = params.options;
    final sourceFile = File(options.sourcePath);

    if (!sourceFile.existsSync()) {
      throw Exception('Source image file not found: ${options.sourcePath}');
    }

    final rawBytes = sourceFile.readAsBytesSync();
    final decoded = await SafeImageDecoder.decodeSafe(rawBytes);
    if (decoded == null) {
      throw Exception('Failed to decode source image');
    }

    // Apply rotation if needed
    img.Image workingSource = decoded;
    if (options.quarterTurns % 4 != 0) {
      final angle = (options.quarterTurns % 4) * 90;
      workingSource = img.copyRotate(workingSource, angle: angle);
    }

    final srcW = workingSource.width;
    final srcH = workingSource.height;
    final origSize = rawBytes.length;

    // Convert normalized coordinates (0.0 - 1.0) to pixel coordinates
    final tlX = (options.topLeft.x * srcW).clamp(0.0, srcW - 1.0);
    final tlY = (options.topLeft.y * srcH).clamp(0.0, srcH - 1.0);
    final trX = (options.topRight.x * srcW).clamp(0.0, srcW - 1.0);
    final trY = (options.topRight.y * srcH).clamp(0.0, srcH - 1.0);
    final brX = (options.bottomRight.x * srcW).clamp(0.0, srcW - 1.0);
    final brY = (options.bottomRight.y * srcH).clamp(0.0, srcH - 1.0);
    final blX = (options.bottomLeft.x * srcW).clamp(0.0, srcW - 1.0);
    final blY = (options.bottomLeft.y * srcH).clamp(0.0, srcH - 1.0);

    // Calculate natural quadrilateral side lengths
    double calcDist(double x1, double y1, double x2, double y2) {
      final dx = x2 - x1;
      final dy = y2 - y1;
      return math.sqrt(dx * dx + dy * dy);
    }

    final topDist = calcDist(tlX, tlY, trX, trY);
    final botDist = calcDist(blX, blY, brX, brY);
    final leftDist = calcDist(tlX, tlY, blX, blY);
    final rightDist = calcDist(trX, trY, brX, brY);

    final naturalW = math.max(topDist, botDist).round().clamp(32, 8192);
    final naturalH = math.max(leftDist, rightDist).round().clamp(32, 8192);

    // Compute target dimensions based on selected preset
    final (targetW, targetH) = _computeTargetDimensions(naturalW, naturalH, options.preset);

    // Allocate output destination frame
    final destImage = img.Image(
      width: targetW,
      height: targetH,
      numChannels: workingSource.numChannels,
    );

    // Perform quadrilateral perspective transformation
    var rectified = img.copyRectify(
      workingSource,
      topLeft: img.Point(tlX, tlY),
      topRight: img.Point(trX, trY),
      bottomLeft: img.Point(blX, blY),
      bottomRight: img.Point(brX, brY),
      toImage: destImage,
      interpolation: img.Interpolation.linear,
    );

    // Apply optional post-processing filters
    rectified = applyFilter(rectified, options.filter);

    // Encode to target format
    final isPng = options.outputFormat.toLowerCase() == 'png';
    final List<int> encodedBytes;
    if (isPng) {
      encodedBytes = img.encodePng(rectified);
    } else {
      encodedBytes = img.encodeJpg(rectified, quality: options.quality.clamp(10, 100));
    }

    // Save rectified output
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = isPng ? 'png' : 'jpg';
    final outputFilePath = p.join(params.outputDirPath, 'perspective_crop_$timestamp.$ext');
    File(outputFilePath).writeAsBytesSync(encodedBytes);

    stopwatch.stop();

    return ProcessResult(
      originalPath: options.sourcePath,
      outputPath: outputFilePath,
      originalSizeBytes: origSize,
      outputSizeBytes: encodedBytes.length,
      originalWidth: decoded.width,
      originalHeight: decoded.height,
      outputWidth: rectified.width,
      outputHeight: rectified.height,
      outputFormat: ext,
      finalQuality: options.quality,
      processingTime: stopwatch.elapsed,
    );
  }

  static (int, int) _computeTargetDimensions(
    int naturalW,
    int naturalH,
    PerspectiveCropPreset preset,
  ) {
    switch (preset) {
      case PerspectiveCropPreset.auto:
        return (naturalW, naturalH);

      case PerspectiveCropPreset.a4:
        // A4 ratio 1 : 1.41421356
        const a4Ratio = 1.41421356;
        if (naturalW <= naturalH) {
          // Portrait
          final targetH = (naturalW * a4Ratio).round().clamp(32, 8192);
          return (naturalW, targetH);
        } else {
          // Landscape
          final targetW = (naturalH * a4Ratio).round().clamp(32, 8192);
          return (targetW, naturalH);
        }

      case PerspectiveCropPreset.idCard:
        // Standard ID Card (85.60 x 53.98) ~ 1.5858
        const idRatio = 1.5858;
        if (naturalW >= naturalH) {
          final targetW = (naturalH * idRatio).round().clamp(32, 8192);
          return (targetW, naturalH);
        } else {
          final targetH = (naturalW * idRatio).round().clamp(32, 8192);
          return (naturalW, targetH);
        }

      case PerspectiveCropPreset.square:
        final side = math.max(naturalW, naturalH).clamp(32, 8192);
        return (side, side);

      case PerspectiveCropPreset.photo4x3:
        if (naturalW >= naturalH) {
          final targetW = (naturalH * (4.0 / 3.0)).round().clamp(32, 8192);
          return (targetW, naturalH);
        } else {
          final targetH = (naturalW * (4.0 / 3.0)).round().clamp(32, 8192);
          return (naturalW, targetH);
        }

      case PerspectiveCropPreset.photo16x9:
        if (naturalW >= naturalH) {
          final targetW = (naturalH * (16.0 / 9.0)).round().clamp(32, 8192);
          return (targetW, naturalH);
        } else {
          final targetH = (naturalW * (16.0 / 9.0)).round().clamp(32, 8192);
          return (naturalW, targetH);
        }
    }
  }

  static img.Image applyFilter(img.Image src, PerspectiveFilter filter) {
    switch (filter) {
      case PerspectiveFilter.none:
        return src;

      case PerspectiveFilter.vividLight:
        return img.adjustColor(
          src,
          contrast: 1.30,
          brightness: 1.15,
          saturation: 1.05,
        );

      case PerspectiveFilter.contrastBw:
        final gray = img.grayscale(src);
        final bw = img.Image(width: gray.width, height: gray.height);
        const threshold = 155;
        for (var y = 0; y < gray.height; y++) {
          for (var x = 0; x < gray.width; x++) {
            final pixel = gray.getPixel(x, y);
            if (pixel.r > threshold) {
              bw.setPixelRgb(x, y, 255, 255, 255);
            } else {
              bw.setPixelRgb(x, y, 0, 0, 0);
            }
          }
        }
        return bw;

      case PerspectiveFilter.grayscale:
        return img.grayscale(src);

      case PerspectiveFilter.documentBw:
        final gray = img.grayscale(src);
        final bw = img.Image(width: gray.width, height: gray.height);

        // Document high-contrast binarization
        const threshold = 145;
        for (var y = 0; y < gray.height; y++) {
          for (var x = 0; x < gray.width; x++) {
            final pixel = gray.getPixel(x, y);
            final lum = pixel.r;
            if (lum > threshold) {
              bw.setPixelRgb(x, y, 255, 255, 255);
            } else {
              bw.setPixelRgb(x, y, 15, 23, 42); // deep navy ink
            }
          }
        }
        return bw;

      case PerspectiveFilter.enhanced:
        // Enhance contrast and vibrance
        return img.adjustColor(
          src,
          contrast: 1.25,
          saturation: 1.15,
          brightness: 1.03,
        );
    }
  }

  /// Applies a document filter to an existing image file in a background isolate.
  static Future<File> applyFilterToFile(
    File inputFile,
    PerspectiveFilter filter, {
    String? outputPath,
    int quality = 90,
    int quarterTurns = 0,
  }) async {
    final targetPath = outputPath ??
        '${inputFile.parent.path}/filtered_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final targetFile = File(targetPath);

    final params = _FilterIsolateParams(
      inputPath: inputFile.path,
      outputPath: targetFile.path,
      filter: filter,
      quality: quality,
      quarterTurns: quarterTurns,
    );

    await compute(_filterIsolateWorker, params);
    return targetFile;
  }

  /// Applies a document filter and returns a ProcessResult suitable for UI/History
  static Future<ProcessResult> processFilter(
    File inputFile,
    PerspectiveFilter filter, {
    String? outputPath,
    int quality = 90,
    int quarterTurns = 0,
  }) async {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
        Platform.environment['FLUTTER_TEST'] == 'true' ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    final stopwatch = Stopwatch()..start();
    String targetDir;
    if (isTest) {
      targetDir = Directory.systemTemp.path;
    } else {
      try {
        final tempDir = await getTemporaryDirectory();
        targetDir = tempDir.path;
      } catch (_) {
        targetDir = Directory.systemTemp.path;
      }
    }

    final targetPath = outputPath ??
        p.join(targetDir, 'doc_filtered_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final targetFile = File(targetPath);

    final params = _FilterIsolateParams(
      inputPath: inputFile.path,
      outputPath: targetFile.path,
      filter: filter,
      quality: quality,
      quarterTurns: quarterTurns,
    );

    final FilterResultData? filterResult;
    if (isTest) {
      filterResult = _filterIsolateWorker(params);
    } else {
      filterResult = await compute(_filterIsolateWorker, params);
    }

    if (filterResult == null || !targetFile.existsSync()) {
      throw Exception('Failed to apply document filter');
    }

    stopwatch.stop();

    return ProcessResult(
      originalPath: inputFile.path,
      outputPath: targetFile.path,
      originalSizeBytes: inputFile.lengthSync(),
      outputSizeBytes: targetFile.lengthSync(),
      originalWidth: filterResult.origW,
      originalHeight: filterResult.origH,
      outputWidth: filterResult.outW,
      outputHeight: filterResult.outH,
      outputFormat: 'jpg',
      finalQuality: quality,
      processingTime: stopwatch.elapsed,
    );
  }
}

class FilterResultData {
  final int origW;
  final int origH;
  final int outW;
  final int outH;

  const FilterResultData({
    required this.origW,
    required this.origH,
    required this.outW,
    required this.outH,
  });
}

class _FilterIsolateParams {
  final String inputPath;
  final String outputPath;
  final PerspectiveFilter filter;
  final int quality;
  final int quarterTurns;

  const _FilterIsolateParams({
    required this.inputPath,
    required this.outputPath,
    required this.filter,
    required this.quality,
    this.quarterTurns = 0,
  });
}

FilterResultData? _filterIsolateWorker(_FilterIsolateParams params) {
  final inFile = File(params.inputPath);
  if (!inFile.existsSync()) return null;
  final bytes = inFile.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  var working = decoded;
  if (params.quarterTurns % 4 != 0) {
    final angle = (params.quarterTurns % 4) * 90;
    working = img.copyRotate(working, angle: angle);
  }

  final filtered = PerspectiveCropper.applyFilter(working, params.filter);
  final encoded = img.encodeJpg(filtered, quality: params.quality);
  File(params.outputPath).writeAsBytesSync(encoded, flush: true);

  return FilterResultData(
    origW: decoded.width,
    origH: decoded.height,
    outW: filtered.width,
    outH: filtered.height,
  );
}

class _PerspectiveIsolateParams {
  final PerspectiveCropOptions options;
  final String outputDirPath;

  const _PerspectiveIsolateParams({
    required this.options,
    required this.outputDirPath,
  });
}

/// Helper providing real-time hardware-accelerated ColorFilter matrices for document filters
class DocumentFilterHelper {
  DocumentFilterHelper._();

  static List<double> getFilterMatrixList(PerspectiveFilter filter) {
    switch (filter) {
      case PerspectiveFilter.none:
        return const <double>[
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case PerspectiveFilter.vividLight:
        return const <double>[
          1.30, 0, 0, 0, 18.0,
          0, 1.30, 0, 0, 18.0,
          0, 0, 1.30, 0, 18.0,
          0, 0, 0, 1, 0,
        ];
      case PerspectiveFilter.contrastBw:
        return const <double>[
          1.2, 3.8, 0.4, 0, -680.0,
          1.2, 3.8, 0.4, 0, -680.0,
          1.2, 3.8, 0.4, 0, -680.0,
          0,   0,   0,   1, 0,
        ];
      case PerspectiveFilter.grayscale:
        return const <double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ];
      case PerspectiveFilter.documentBw:
        return const <double>[
          0.8504, 2.8608, 0.2888, 0, -540.0,
          0.8504, 2.8608, 0.2888, 0, -540.0,
          0.8504, 2.8608, 0.2888, 0, -540.0,
          0,      0,      0,      1, 0,
        ];
      case PerspectiveFilter.enhanced:
        return const <double>[
          1.3976, -0.1341, -0.0135, 0, -24.0,
          -0.0399, 1.3034, -0.0135, 0, -24.0,
          -0.0399, -0.1341, 1.4240, 0, -24.0,
          0,       0,       0,      1, 0,
        ];
    }
  }

  static ColorFilter? getColorFilter(PerspectiveFilter filter) {
    if (filter == PerspectiveFilter.none) return null;
    return ColorFilter.matrix(getFilterMatrixList(filter));
  }
}
