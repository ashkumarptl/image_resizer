import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/extensions/file_size_extension.dart';
import '../../../data/models/process_options.dart';
import '../../../services/image_service/image_processor.dart';

/// Represents an individual image within a batch processing selection
class BatchItemModel {
  final File file;
  final int fileSizeBytes;
  final ImageDimensions? dimensions;
  final ProcessOptions? customOptions;

  const BatchItemModel({
    required this.file,
    required this.fileSizeBytes,
    this.dimensions,
    this.customOptions,
  });

  String get path => file.path;
  String get fileName => p.basename(file.path);
  String get readableSize => fileSizeBytes.toReadableFileSize();
  bool get hasCustomOptions => customOptions != null;

  String get resolutionString => dimensions != null
      ? '${dimensions!.width}×${dimensions!.height}'
      : 'Loading...';

  BatchItemModel copyWith({
    File? file,
    int? fileSizeBytes,
    ImageDimensions? dimensions,
    ProcessOptions? customOptions,
    bool clearCustomOptions = false,
  }) {
    return BatchItemModel(
      file: file ?? this.file,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      dimensions: dimensions ?? this.dimensions,
      customOptions: clearCustomOptions
          ? null
          : (customOptions ?? this.customOptions),
    );
  }

  /// Factory to initialize from File with synchronous size and placeholder dimensions
  static BatchItemModel fromFile(File file) {
    var size = 0;
    try {
      if (file.existsSync()) {
        size = file.lengthSync();
      }
    } catch (_) {}

    return BatchItemModel(file: file, fileSizeBytes: size);
  }
}
