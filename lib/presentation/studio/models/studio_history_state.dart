import 'dart:io';
import '../widgets/compress_options_sheet.dart';
import '../widgets/resize_options_sheet.dart';

/// Represents an immutable snapshot of adjustments made in ImageStudioScreen.
class StudioHistoryState {
  final File imageFile;
  final int originalWidth;
  final int originalHeight;
  final int fileSizeBytes;
  final int quarterTurns;
  final bool flipHorizontal;
  final bool flipVertical;
  final bool hasCropped;
  final bool hasRemovedBg;
  final ResizeSheetOption resizeOption;
  final int targetWidth;
  final int targetHeight;
  final int selectedPercentage;
  final bool keepAspectRatio;
  final CompressionSheetMode compressionMode;
  final int selectedTargetSizeKB;
  final double quality;
  final String outputFormat;
  final int? imageDpi;
  final int? targetDpi;

  const StudioHistoryState({
    required this.imageFile,
    required this.originalWidth,
    required this.originalHeight,
    required this.fileSizeBytes,
    required this.quarterTurns,
    required this.flipHorizontal,
    required this.flipVertical,
    required this.hasCropped,
    required this.hasRemovedBg,
    required this.resizeOption,
    required this.targetWidth,
    required this.targetHeight,
    required this.selectedPercentage,
    required this.keepAspectRatio,
    required this.compressionMode,
    required this.selectedTargetSizeKB,
    required this.quality,
    required this.outputFormat,
    this.imageDpi,
    this.targetDpi,
  });

  bool matches(StudioHistoryState other) {
    return imageFile.path == other.imageFile.path &&
        originalWidth == other.originalWidth &&
        originalHeight == other.originalHeight &&
        fileSizeBytes == other.fileSizeBytes &&
        quarterTurns == other.quarterTurns &&
        flipHorizontal == other.flipHorizontal &&
        flipVertical == other.flipVertical &&
        hasCropped == other.hasCropped &&
        hasRemovedBg == other.hasRemovedBg &&
        resizeOption == other.resizeOption &&
        targetWidth == other.targetWidth &&
        targetHeight == other.targetHeight &&
        selectedPercentage == other.selectedPercentage &&
        keepAspectRatio == other.keepAspectRatio &&
        compressionMode == other.compressionMode &&
        selectedTargetSizeKB == other.selectedTargetSizeKB &&
        quality == other.quality &&
        outputFormat == other.outputFormat &&
        imageDpi == other.imageDpi &&
        targetDpi == other.targetDpi;
  }
}
