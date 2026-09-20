import 'dart:io';
import 'dart:math' as math;
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/process_options.dart';
import '../../data/models/process_result.dart';
import 'image_processor.dart';

/// Progress information for batch processing
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

/// Record of an image that failed during batch processing
class BatchFailure {
  final String path;
  final String fileName;
  final String errorMessage;

  const BatchFailure({
    required this.path,
    required this.fileName,
    required this.errorMessage,
  });

  @override
  String toString() => '$fileName: $errorMessage';
}

/// Token to allow cancellation of an ongoing batch process
class BatchCancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// Summary result of a batch processing operation
class BatchResult {
  final List<ProcessResult> results;
  final List<BatchFailure> failures;
  final String? zipFilePath;
  final Duration totalDuration;
  final bool isCancelled;

  const BatchResult({
    required this.results,
    this.failures = const [],
    this.zipFilePath,
    required this.totalDuration,
    this.isCancelled = false,
  });

  bool get hasFailures => failures.isNotEmpty;
  int get successCount => results.length;
  int get failureCount => failures.length;
}

class BatchProcessor {
  BatchProcessor._();

  /// Process multiple images using controlled worker concurrency and report progress.
  /// Supports cancellation via [cancellationToken] and granular failure tracking.
  static Future<BatchResult> processBatch({
    required List<String> sourceFilePaths,
    required ProcessOptions baseOptions,
    Map<String, ProcessOptions>? itemOverrides,
    bool createZip = true,
    Function(BatchProgress progress)? onProgress,
    BatchCancellationToken? cancellationToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    final total = sourceFilePaths.length;
    if (total == 0) {
      return const BatchResult(
        results: [],
        failures: [],
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
    final failures = <BatchFailure>[];
    int completedCount = 0;
    int nextIndex = 0;

    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    // Concurrency limit: 2 to 4 parallel workers on multi-core systems, avoiding OOM while boosting speed
    final concurrency = isTest
        ? 1
        : math.min(math.max(1, Platform.numberOfProcessors - 1), 4);

    Future<void> worker() async {
      while (true) {
        if (cancellationToken != null && cancellationToken.isCancelled) {
          break;
        }
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
          failures.add(
            BatchFailure(
              path: path,
              fileName: fileName,
              errorMessage: e.toString(),
            ),
          );
          onProgress?.call(
            BatchProgress(
              completed: completedCount,
              total: total,
              currentFileName: fileName,
            ),
          );
        }
      }
    }

    await Future.wait(
      List.generate(math.min(concurrency, total), (_) => worker()),
    );

    final results = indexedResults.whereType<ProcessResult>().toList();

    String? zipPath;
    if (createZip &&
        results.isNotEmpty &&
        !(cancellationToken?.isCancelled ?? false)) {
      zipPath = await _createZipArchive(results);
    }

    stopwatch.stop();

    return BatchResult(
      results: results,
      failures: failures,
      zipFilePath: zipPath,
      totalDuration: stopwatch.elapsed,
      isCancelled: cancellationToken?.isCancelled ?? false,
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
    final zipFilePath = p.join(
      cacheDirPath,
      'image_tools_batch_$timestamp.zip',
    );

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

  static String _runZipWorker(_ZipWorkerParams params) {
    final archive = Archive();

    for (final path in params.filePaths) {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        final name = p.basename(path);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
    }

    final zipData = ZipEncoder().encode(archive);
    final zipFile = File(params.zipFilePath);
    zipFile.writeAsBytesSync(zipData);
    return zipFile.path;
  }
}

class _ZipWorkerParams {
  final String zipFilePath;
  final List<String> filePaths;

  const _ZipWorkerParams({required this.zipFilePath, required this.filePaths});
}
