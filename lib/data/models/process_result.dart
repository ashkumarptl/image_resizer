import 'package:flutter/foundation.dart';

@immutable
class ProcessResult {
  final String originalPath;
  final String outputPath;
  final int originalSizeBytes;
  final int outputSizeBytes;
  final int originalWidth;
  final int originalHeight;
  final int outputWidth;
  final int outputHeight;
  final String outputFormat;
  final int finalQuality;
  final Duration processingTime;

  const ProcessResult({
    required this.originalPath,
    required this.outputPath,
    required this.originalSizeBytes,
    required this.outputSizeBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.outputWidth,
    required this.outputHeight,
    required this.outputFormat,
    required this.finalQuality,
    required this.processingTime,
  });

  /// Percentage saved (e.g. 78.5% saved, or negative if grew)
  double get savedPercentage {
    if (originalSizeBytes <= 0) return 0;
    return ((originalSizeBytes - outputSizeBytes) / originalSizeBytes) * 100;
  }

  bool get isSizeReduced => outputSizeBytes < originalSizeBytes;
}
