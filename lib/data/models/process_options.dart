enum ResizeMode { none, exactPixels, percentage }

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
  final int quarterTurns;
  final bool flipHorizontal;
  final bool flipVertical;
  final bool preventSizeIncrease;
  final bool stripMetadata;
  final int? targetDpi;

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
    this.quarterTurns = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.preventSizeIncrease = true,
    this.stripMetadata = true,
    this.targetDpi,
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
    int? quarterTurns,
    bool? flipHorizontal,
    bool? flipVertical,
    bool? preventSizeIncrease,
    bool? stripMetadata,
    int? targetDpi,
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
      quarterTurns: quarterTurns ?? this.quarterTurns,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      preventSizeIncrease: preventSizeIncrease ?? this.preventSizeIncrease,
      stripMetadata: stripMetadata ?? this.stripMetadata,
      targetDpi: targetDpi ?? this.targetDpi,
    );
  }
}
