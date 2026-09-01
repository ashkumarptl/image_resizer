import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/process_options.dart';
import '../../data/models/process_result.dart';
import 'image_processor.dart';

class BatchProgress {
  final int completed;
  final int total;
  final ProcessResult? latestResult;
  final String currentFileName;

  const BatchProgress({
    required this.completed,
    required this.total,
    this.latestResult,
    required this.currentFileName,
  });

  double get percentage => total == 0 ? 0 : completed / total;
}

class BatchResult {
  final List<ProcessResult> results;
  final String? zipFilePath;
  final Duration totalDuration;

  const BatchResult({
    required this.results,
    this.zipFilePath,
    required this.totalDuration,
  });
}

class BatchProcessor {
  BatchProcessor._();

  /// Process multiple images sequentially and report progress
  static Future<BatchResult> processBatch({
    required List<String> sourceFilePaths,
    required ProcessOptions baseOptions,
    bool createZip = true,
    Function(BatchProgress progress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final results = <ProcessResult>[];
    final total = sourceFilePaths.length;

    for (var i = 0; i < total; i++) {
      final path = sourceFilePaths[i];
      final fileName = p.basename(path);

      onProgress?.call(
        BatchProgress(
          completed: i,
          total: total,
          currentFileName: fileName,
        ),
      );

      final itemOptions = baseOptions.copyWith(sourcePath: path);
      try {
        final result = await ImageProcessor.processImage(itemOptions);
        results.add(result);

        onProgress?.call(
          BatchProgress(
            completed: i + 1,
            total: total,
            latestResult: result,
            currentFileName: fileName,
          ),
        );
      } catch (e) {
        debugPrint('Error processing $path in batch: $e');
      }
    }

    String? zipPath;
    if (createZip && results.isNotEmpty) {
      zipPath = await _createZipArchive(results);
    }

    stopwatch.stop();

    return BatchResult(
      results: results,
      zipFilePath: zipPath,
      totalDuration: stopwatch.elapsed,
    );
  }

  /// Create a zip archive containing all output files
  static Future<String> _createZipArchive(List<ProcessResult> results) async {
    final cacheDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipFile = File(p.join(cacheDir.path, 'image_tools_batch_$timestamp.zip'));

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);

    for (final result in results) {
      final file = File(result.outputPath);
      if (file.existsSync()) {
        encoder.addFile(file);
      }
    }

    encoder.close();
    return zipFile.path;
  }
}
