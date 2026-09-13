import 'dart:io';
import 'dart:math' as math;
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

  /// Process multiple images using controlled worker concurrency and report progress
  static Future<BatchResult> processBatch({
    required List<String> sourceFilePaths,
    required ProcessOptions baseOptions,
    Map<String, ProcessOptions>? itemOverrides,
    bool createZip = true,
    Function(BatchProgress progress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final total = sourceFilePaths.length;
    if (total == 0) {
      return BatchResult(
        results: const [],
        zipFilePath: null,
        totalDuration: Duration.zero,
      );
    }

    onProgress?.call(
      BatchProgress(
        completed: 0,
        total: total,
        currentFileName: p.basename(sourceFilePaths.first),
      ),
    );

    final indexedResults = List<ProcessResult?>.filled(total, null);
    int completedCount = 0;
    int nextIndex = 0;

    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    // Concurrency limit: 2 to 3 parallel workers on multi-core systems, avoiding OOM while boosting speed
    final concurrency = isTest
        ? 1
        : math.min(math.max(1, Platform.numberOfProcessors - 1), 3);

    Future<void> worker() async {
      while (true) {
        if (nextIndex >= total) break;
        final i = nextIndex++;
        final path = sourceFilePaths[i];
        final fileName = p.basename(path);

        final itemOptions =
            (itemOverrides != null && itemOverrides.containsKey(path))
            ? itemOverrides[path]!.copyWith(sourcePath: path)
            : baseOptions.copyWith(sourcePath: path);

        try {
          final result = await ImageProcessor.processImage(itemOptions);
          indexedResults[i] = result;
          completedCount++;
          onProgress?.call(
            BatchProgress(
              completed: completedCount,
              total: total,
              latestResult: result,
              currentFileName: fileName,
            ),
          );
        } catch (e) {
          completedCount++;
          debugPrint('Error processing $path in batch: $e');
        }
      }
    }

    await Future.wait(
      List.generate(math.min(concurrency, total), (_) => worker()),
    );

    final results = indexedResults.whereType<ProcessResult>().toList();

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

  /// Create a zip archive containing all output files in a background isolate
  static Future<String> _createZipArchive(List<ProcessResult> results) async {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    String cacheDirPath;
    if (isTest) {
      cacheDirPath = Directory.systemTemp.path;
    } else {
      try {
        final cacheDir = await getTemporaryDirectory();
        cacheDirPath = cacheDir.path;
      } catch (_) {
        cacheDirPath = Directory.systemTemp.path;
      }
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipFilePath = p.join(cacheDirPath, 'image_tools_batch_$timestamp.zip');

    final filePaths = results
        .map((r) => r.outputPath)
        .where((path) => File(path).existsSync())
        .toList();

    final params = _ZipWorkerParams(
      zipFilePath: zipFilePath,
      filePaths: filePaths,
    );

    if (isTest) {
      return _runZipWorker(params);
    }

    return compute(_runZipWorker, params);
  }
}

class _ZipWorkerParams {
  final String zipFilePath;
  final List<String> filePaths;

  const _ZipWorkerParams({
    required this.zipFilePath,
    required this.filePaths,
  });
}

String _runZipWorker(_ZipWorkerParams params) {
  final zipFile = File(params.zipFilePath);
  if (!zipFile.parent.existsSync()) {
    zipFile.parent.createSync(recursive: true);
  }

  final encoder = ZipFileEncoder();
  encoder.create(zipFile.path);

  for (final path in params.filePaths) {
    final file = File(path);
    if (file.existsSync()) {
      encoder.addFile(file);
    }
  }

  encoder.close();
  return zipFile.path;
}
