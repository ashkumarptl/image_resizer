import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/process_options.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/usage_limit_repository.dart';
import '../../../../services/analytics_service.dart';
import '../../../../services/crashlytics_service.dart';
import '../../../../services/image_service/batch_processor.dart';
import '../../../../services/image_service/image_processor.dart';
import '../models/batch_item_model.dart';

enum BatchMode { targetSize, scalePercentage }

@immutable
class BatchState {
  final List<BatchItemModel> items;
  final Set<String> selectedPaths;
  final bool isProcessing;
  final BatchProgress? progress;
  final BatchResult? batchResult;
  final BatchMode activeMode;
  final int selectedTargetSizeKB;
  final int selectedScalePercentage;
  final String outputFormat;
  final String? focusedItemPath;

  const BatchState({
    this.items = const [],
    this.selectedPaths = const {},
    this.isProcessing = false,
    this.progress,
    this.batchResult,
    this.activeMode = BatchMode.targetSize,
    this.selectedTargetSizeKB = 100,
    this.selectedScalePercentage = 100,
    this.outputFormat = 'jpg',
    this.focusedItemPath,
  });

  BatchItemModel? get focusedItem {
    if (focusedItemPath != null) {
      try {
        return items.firstWhere((it) => it.path == focusedItemPath);
      } catch (_) {}
    }
    if (selectedPaths.length == 1) {
      try {
        return items.firstWhere((it) => it.path == selectedPaths.first);
      } catch (_) {}
    }
    return null;
  }

  int get totalSelectedBytes =>
      items.fold(0, (sum, it) => sum + it.fileSizeBytes);

  int get customizedItemCount =>
      items.where((it) => it.hasCustomOptions).length;

  bool get canProcess => items.isNotEmpty && !isProcessing;

  bool get hasSelection => selectedPaths.isNotEmpty;
  int get selectionCount => selectedPaths.length;
  bool get isAllSelected =>
      items.isNotEmpty && selectedPaths.length == items.length;

  /// Real-time live estimate of the total batch output size based on current settings
  int get estimatedTotalOutputBytes {
    if (items.isEmpty) return 0;
    var estSum = 0;
    for (final item in items) {
      final opts = item.customOptions ?? createBaseOptions();
      var itemEst = item.fileSizeBytes;

      if (opts.targetSizeKB != null) {
        final targetBytes = opts.targetSizeKB! * 1024;
        itemEst = item.fileSizeBytes > targetBytes
            ? targetBytes
            : item.fileSizeBytes;
      } else if (opts.resizePercentage != null &&
          opts.resizePercentage! < 100) {
        final scaleRatio = opts.resizePercentage! / 100.0;
        final scaledBytes = (item.fileSizeBytes * (scaleRatio * scaleRatio))
            .round();
        itemEst = scaledBytes < item.fileSizeBytes
            ? scaledBytes
            : item.fileSizeBytes;
      }

      // WEBP is typically ~25-30% more efficient than JPG/PNG
      if (opts.outputFormat.toLowerCase() == 'webp') {
        itemEst = (itemEst * 0.82).round();
      }

      estSum += itemEst > 0 ? itemEst : 1024;
    }
    return estSum;
  }

  int get estimatedSavedBytes {
    final diff = totalSelectedBytes - estimatedTotalOutputBytes;
    return diff > 0 ? diff : 0;
  }

  double get estimatedSavedPercentage {
    if (totalSelectedBytes <= 0) return 0.0;
    return ((estimatedSavedBytes / totalSelectedBytes) * 100).clamp(0.0, 99.0);
  }

  ProcessOptions createBaseOptions() {
    return ProcessOptions(
      sourcePath: '',
      targetSizeKB: activeMode == BatchMode.targetSize
          ? selectedTargetSizeKB
          : null,
      outputFormat: outputFormat,
      resizeMode:
          activeMode == BatchMode.scalePercentage &&
              selectedScalePercentage != 100
          ? ResizeMode.percentage
          : ResizeMode.none,
      resizePercentage:
          activeMode == BatchMode.scalePercentage &&
              selectedScalePercentage != 100
          ? selectedScalePercentage
          : null,
      preventSizeIncrease: true,
    );
  }

  BatchState copyWith({
    List<BatchItemModel>? items,
    Set<String>? selectedPaths,
    bool? isProcessing,
    BatchProgress? progress,
    bool clearProgress = false,
    BatchResult? batchResult,
    bool clearBatchResult = false,
    BatchMode? activeMode,
    int? selectedTargetSizeKB,
    int? selectedScalePercentage,
    String? outputFormat,
    String? focusedItemPath,
    bool clearFocusedItem = false,
  }) {
    return BatchState(
      items: items ?? this.items,
      selectedPaths: selectedPaths ?? this.selectedPaths,
      isProcessing: isProcessing ?? this.isProcessing,
      progress: clearProgress ? null : (progress ?? this.progress),
      batchResult: clearBatchResult ? null : (batchResult ?? this.batchResult),
      activeMode: activeMode ?? this.activeMode,
      selectedTargetSizeKB: selectedTargetSizeKB ?? this.selectedTargetSizeKB,
      selectedScalePercentage:
          selectedScalePercentage ?? this.selectedScalePercentage,
      outputFormat: outputFormat ?? this.outputFormat,
      focusedItemPath: clearFocusedItem
          ? null
          : (focusedItemPath ?? this.focusedItemPath),
    );
  }
}

class BatchNotifier extends StateNotifier<BatchState> {
  final Ref _ref;

  BatchNotifier(this._ref, [List<File>? initialFiles])
    : super(const BatchState()) {
    if (initialFiles != null && initialFiles.isNotEmpty) {
      setInitialFiles(initialFiles);
    }
  }

  void setInitialFiles(List<File> files) {
    final newItems = files.map((f) => BatchItemModel.fromFile(f)).toList();
    state = state.copyWith(items: newItems, clearBatchResult: true);
    loadDimensionsForItems(newItems);
  }

  Future<void> loadDimensionsForItems(List<BatchItemModel> itemsToLoad) async {
    if (itemsToLoad.isEmpty) return;

    final results = await Future.wait(
      itemsToLoad.map((item) async {
        final dims = await ImageProcessor.readImageDimensions(item.path);
        return (item.path, dims);
      }),
    );

    final dimMap = {
      for (final r in results)
        if (r.$2 != null) r.$1: r.$2!,
    };

    if (dimMap.isNotEmpty) {
      final updatedItems = state.items.map((it) {
        if (dimMap.containsKey(it.path)) {
          return it.copyWith(dimensions: dimMap[it.path]);
        }
        return it;
      }).toList();
      state = state.copyWith(items: updatedItems);
    }
  }

  void addFiles(List<File> files, {bool append = false}) {
    final newItems = files.map((f) => BatchItemModel.fromFile(f)).toList();
    final updatedList = append ? [...state.items, ...newItems] : newItems;
    state = state.copyWith(items: updatedList, clearBatchResult: true);
    loadDimensionsForItems(newItems);
  }

  void removeItemAt(int index) {
    if (index >= 0 && index < state.items.length) {
      final removed = state.items[index];
      final updatedList = List<BatchItemModel>.from(state.items)
        ..removeAt(index);
      final updatedSelection = Set<String>.from(state.selectedPaths)
        ..remove(removed.path);
      state = state.copyWith(
        items: updatedList,
        selectedPaths: updatedSelection,
        clearFocusedItem: state.focusedItemPath == removed.path,
        clearBatchResult: updatedList.isEmpty,
      );
    }
  }

  void reorderItems(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= state.items.length ||
        newIndex < 0 ||
        newIndex > state.items.length) {
      return;
    }
    final items = List<BatchItemModel>.from(state.items);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = state.copyWith(items: items);
  }

  void toggleItemSelection(String path) {
    final updated = Set<String>.from(state.selectedPaths);
    String? nextFocus = state.focusedItemPath;
    if (updated.contains(path)) {
      updated.remove(path);
      if (nextFocus == path) {
        nextFocus = updated.isNotEmpty ? updated.last : null;
      }
    } else {
      updated.add(path);
      nextFocus = path;
    }
    state = state.copyWith(
      selectedPaths: updated,
      focusedItemPath: nextFocus,
      clearFocusedItem: nextFocus == null,
    );
  }

  void selectAll() {
    state = state.copyWith(
      selectedPaths: state.items.map((it) => it.path).toSet(),
      focusedItemPath: state.items.isNotEmpty ? state.items.first.path : null,
      clearFocusedItem: state.items.isEmpty,
    );
  }

  void deselectAll() {
    state = state.copyWith(selectedPaths: {}, clearFocusedItem: true);
  }

  void removeSelectedItems() {
    if (state.selectedPaths.isEmpty) return;
    final clearFocus =
        state.focusedItemPath != null &&
        state.selectedPaths.contains(state.focusedItemPath);
    final updatedList = state.items
        .where((it) => !state.selectedPaths.contains(it.path))
        .toList();
    state = state.copyWith(
      items: updatedList,
      selectedPaths: {},
      clearFocusedItem: clearFocus,
      clearBatchResult: updatedList.isEmpty,
    );
  }

  void applyCurrentSettingsToSelected() {
    if (state.selectedPaths.isEmpty) return;
    final baseOpts = state.createBaseOptions();
    final updatedList = state.items.map((it) {
      if (state.selectedPaths.contains(it.path)) {
        return it.copyWith(
          customOptions: baseOpts.copyWith(sourcePath: it.path),
        );
      }
      return it;
    }).toList();

    state = state.copyWith(items: updatedList, selectedPaths: {});
  }

  void clearAll() {
    state = state.copyWith(
      items: [],
      selectedPaths: {},
      clearFocusedItem: true,
      clearBatchResult: true,
    );
  }

  void updateItemAt(int index, BatchItemModel item) {
    if (index >= 0 && index < state.items.length) {
      final updatedList = List<BatchItemModel>.from(state.items);
      updatedList[index] = item;
      state = state.copyWith(items: updatedList);
    }
  }

  void setItemCustomOptions(int index, ProcessOptions? customOpts) {
    if (index >= 0 && index < state.items.length) {
      final updatedList = List<BatchItemModel>.from(state.items);
      if (customOpts != null) {
        updatedList[index] = updatedList[index].copyWith(
          customOptions: customOpts,
        );
      } else {
        updatedList[index] = updatedList[index].copyWith(
          clearCustomOptions: true,
        );
      }
      state = state.copyWith(items: updatedList);
    }
  }

  void resetAllCustomOverrides() {
    final updatedList = state.items
        .map((it) => it.copyWith(clearCustomOptions: true))
        .toList();
    state = state.copyWith(items: updatedList);
  }

  void setFocusedItem(String? path) {
    if (path == null) {
      state = state.copyWith(clearFocusedItem: true, selectedPaths: {});
    } else {
      state = state.copyWith(focusedItemPath: path, selectedPaths: {path});
    }
  }

  void clearFocusedItem() {
    state = state.copyWith(clearFocusedItem: true, selectedPaths: {});
  }

  void resetFocusedItemOptions() {
    final focused = state.focusedItem;
    if (focused == null) return;
    final index = state.items.indexWhere((it) => it.path == focused.path);
    if (index != -1) {
      final updatedList = List<BatchItemModel>.from(state.items);
      updatedList[index] = updatedList[index].copyWith(
        clearCustomOptions: true,
      );
      state = state.copyWith(items: updatedList);
    }
  }

  void resetSelectedItemsOptions() {
    if (state.selectedPaths.isEmpty) {
      resetFocusedItemOptions();
      return;
    }
    final updatedList = state.items.map((it) {
      if (state.selectedPaths.contains(it.path)) {
        return it.copyWith(clearCustomOptions: true);
      }
      return it;
    }).toList();
    state = state.copyWith(items: updatedList);
  }

  void setActiveMode(BatchMode mode) {
    if (state.selectedPaths.isNotEmpty) {
      final updatedList = state.items.map((it) {
        if (state.selectedPaths.contains(it.path)) {
          final curOpts = it.customOptions ?? state.createBaseOptions();
          return it.copyWith(
            customOptions: curOpts.copyWith(
              resizeMode: mode == BatchMode.scalePercentage
                  ? ResizeMode.percentage
                  : ResizeMode.none,
            ),
          );
        }
        return it;
      }).toList();
      state = state.copyWith(items: updatedList);
    } else if (state.focusedItem != null) {
      final focused = state.focusedItem!;
      final curOpts = focused.customOptions ?? state.createBaseOptions();
      final updatedOpts = curOpts.copyWith(
        resizeMode: mode == BatchMode.scalePercentage
            ? ResizeMode.percentage
            : ResizeMode.none,
      );
      final index = state.items.indexWhere((it) => it.path == focused.path);
      if (index != -1) {
        final updatedList = List<BatchItemModel>.from(state.items);
        updatedList[index] = updatedList[index].copyWith(
          customOptions: updatedOpts,
        );
        state = state.copyWith(items: updatedList);
      }
    } else {
      state = state.copyWith(activeMode: mode);
    }
  }

  void setTargetSizeKB(int kb) {
    if (state.selectedPaths.isNotEmpty) {
      final updatedList = state.items.map((it) {
        if (state.selectedPaths.contains(it.path)) {
          final curOpts = it.customOptions ?? state.createBaseOptions();
          return it.copyWith(customOptions: curOpts.copyWith(targetSizeKB: kb));
        }
        return it;
      }).toList();
      state = state.copyWith(items: updatedList);
    } else if (state.focusedItem != null) {
      final focused = state.focusedItem!;
      final curOpts = focused.customOptions ?? state.createBaseOptions();
      final updatedOpts = curOpts.copyWith(targetSizeKB: kb);
      final index = state.items.indexWhere((it) => it.path == focused.path);
      if (index != -1) {
        final updatedList = List<BatchItemModel>.from(state.items);
        updatedList[index] = updatedList[index].copyWith(
          customOptions: updatedOpts,
        );
        state = state.copyWith(items: updatedList);
      }
    } else {
      state = state.copyWith(selectedTargetSizeKB: kb);
    }
  }

  void setScalePercentage(int pct) {
    if (state.selectedPaths.isNotEmpty) {
      final updatedList = state.items.map((it) {
        if (state.selectedPaths.contains(it.path)) {
          final curOpts = it.customOptions ?? state.createBaseOptions();
          return it.copyWith(
            customOptions: curOpts.copyWith(
              resizeMode: pct != 100 ? ResizeMode.percentage : ResizeMode.none,
              resizePercentage: pct != 100 ? pct : null,
            ),
          );
        }
        return it;
      }).toList();
      state = state.copyWith(items: updatedList);
    } else if (state.focusedItem != null) {
      final focused = state.focusedItem!;
      final curOpts = focused.customOptions ?? state.createBaseOptions();
      final updatedOpts = curOpts.copyWith(
        resizeMode: pct != 100 ? ResizeMode.percentage : ResizeMode.none,
        resizePercentage: pct != 100 ? pct : null,
      );
      final index = state.items.indexWhere((it) => it.path == focused.path);
      if (index != -1) {
        final updatedList = List<BatchItemModel>.from(state.items);
        updatedList[index] = updatedList[index].copyWith(
          customOptions: updatedOpts,
        );
        state = state.copyWith(items: updatedList);
      }
    } else {
      state = state.copyWith(selectedScalePercentage: pct);
    }
  }

  void setOutputFormat(String format) {
    if (state.selectedPaths.isNotEmpty) {
      final updatedList = state.items.map((it) {
        if (state.selectedPaths.contains(it.path)) {
          final curOpts = it.customOptions ?? state.createBaseOptions();
          return it.copyWith(
            customOptions: curOpts.copyWith(outputFormat: format),
          );
        }
        return it;
      }).toList();
      state = state.copyWith(items: updatedList);
    } else if (state.focusedItem != null) {
      final focused = state.focusedItem!;
      final curOpts = focused.customOptions ?? state.createBaseOptions();
      final updatedOpts = curOpts.copyWith(outputFormat: format);
      final index = state.items.indexWhere((it) => it.path == focused.path);
      if (index != -1) {
        final updatedList = List<BatchItemModel>.from(state.items);
        updatedList[index] = updatedList[index].copyWith(
          customOptions: updatedOpts,
        );
        state = state.copyWith(items: updatedList);
      }
    } else {
      state = state.copyWith(outputFormat: format);
    }
  }

  BatchCancellationToken? _activeCancellationToken;

  void cancelCurrentBatch() {
    _activeCancellationToken?.cancel();
  }

  void resetResult() {
    state = state.copyWith(clearBatchResult: true);
  }

  Future<BatchResult> processBatch({List<String>? specificPaths}) async {
    final pathsToProcess =
        specificPaths ?? state.items.map((f) => f.path).toList();
    if (pathsToProcess.isEmpty) {
      throw StateError('No images selected for batch processing');
    }

    _activeCancellationToken = BatchCancellationToken();

    state = state.copyWith(
      isProcessing: true,
      clearBatchResult: specificPaths == null,
      clearProgress: true,
    );

    final totalCount = pathsToProcess.length;
    await AnalyticsService.logBatchResizeStarted(count: totalCount);
    await CrashlyticsService.setProcessingContext(
      operation: 'batch_resize',
      inputWidth: 0,
      inputHeight: 0,
      inputSizeKb: 0,
      outputFormat: state.outputFormat,
    );

    final baseOptions = state.createBaseOptions();
    final overrides = <String, ProcessOptions>{};
    for (final it in state.items) {
      if (it.customOptions != null && pathsToProcess.contains(it.path)) {
        overrides[it.path] = it.customOptions!;
      }
    }

    try {
      final result = await BatchProcessor.processBatch(
        sourceFilePaths: pathsToProcess,
        baseOptions: baseOptions,
        itemOverrides: overrides.isNotEmpty ? overrides : null,
        createZip: true,
        cancellationToken: _activeCancellationToken,
        onProgress: (prog) {
          state = state.copyWith(progress: prog);
        },
      );

      AnalyticsService.logBatchResizeCompleted(
        totalImages: totalCount,
        successCount: result.results.length,
        failedCount: result.failures.length,
        durationMs: result.totalDuration.inMilliseconds,
      );
      await CrashlyticsService.clearProcessingContext();

      // Increment guest usage count if unauthenticated & not developer
      final isDeveloper = _ref.read(isDeveloperProvider);
      final user = _ref.read(currentUserProvider);
      if (user == null && !isDeveloper && result.results.isNotEmpty) {
        await _ref.read(guestUsageCountProvider.notifier).increment();
      }

      // If this was a retry of specific paths, merge with existing results
      final finalResult = (specificPaths != null && state.batchResult != null)
          ? BatchResult(
              results: [...state.batchResult!.results, ...result.results],
              failures: result.failures,
              zipFilePath: result.zipFilePath ?? state.batchResult!.zipFilePath,
              totalDuration:
                  state.batchResult!.totalDuration + result.totalDuration,
              isCancelled: result.isCancelled,
            )
          : result;

      state = state.copyWith(isProcessing: false, batchResult: finalResult);
      return finalResult;
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(
        e,
        stack,
        reason: 'Batch processing failure',
      );
      state = state.copyWith(isProcessing: false);
      rethrow;
    } finally {
      _activeCancellationToken = null;
    }
  }

  /// Retries only the images that previously failed during processing
  Future<BatchResult?> retryFailedItems() async {
    final failures = state.batchResult?.failures;
    if (failures == null || failures.isEmpty) return null;

    final failedPaths = failures.map((f) => f.path).toList();
    return processBatch(specificPaths: failedPaths);
  }
}

final batchNotifierProvider = StateNotifierProvider.autoDispose
    .family<BatchNotifier, BatchState, List<File>?>(
      (ref, initialFiles) => BatchNotifier(ref, initialFiles),
    );
