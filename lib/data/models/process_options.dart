enum ResizeMode {
  none,
  exactPixels,
  percentage,
}

class ProcessOptions {
  final String sourcePath;
  final int? targetSizeKB;
  final int quality;
  final String outputFormat; // 'jpg', 'png', 'webp'
  final ResizeMode resizeMode;
  final int? targetWidth;
  final int? targetHeight;
  final int? resizePercentage;
  final bool keepAspectRatio;
  final bool strictDimensions;

  const ProcessOptions({
    required this.sourcePath,
    this.targetSizeKB,
    this.quality = 85,
    this.outputFormat = 'jpg',
    this.resizeMode = ResizeMode.none,
    this.targetWidth,
    this.targetHeight,
    this.resizePercentage,
    this.keepAspectRatio = true,
    this.strictDimensions = false,
  });

  ProcessOptions copyWith({
    String? sourcePath,
    int? targetSizeKB,
    int? quality,
    String? outputFormat,
    ResizeMode? resizeMode,
    int? targetWidth,
    int? targetHeight,
    int? resizePercentage,
    bool? keepAspectRatio,
    bool? strictDimensions,
  }) {
    return ProcessOptions(
      sourcePath: sourcePath ?? this.sourcePath,
      targetSizeKB: targetSizeKB ?? this.targetSizeKB,
      quality: quality ?? this.quality,
      outputFormat: outputFormat ?? this.outputFormat,
      resizeMode: resizeMode ?? this.resizeMode,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      resizePercentage: resizePercentage ?? this.resizePercentage,
      keepAspectRatio: keepAspectRatio ?? this.keepAspectRatio,
      strictDimensions: strictDimensions ?? this.strictDimensions,
    );
  }
}
