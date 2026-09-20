import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/process_options.dart';
import '../../data/models/process_result.dart';
import '../../services/image_service/image_processor.dart';
import '../../services/scanner/document_scanner_service.dart';
import '../../services/share_service.dart';
import '../../services/storage_service.dart';
import '../studio/image_studio_screen.dart';
import '../widgets/gradient_button.dart';
import '../widgets/login_gate_dialog.dart';
import '../widgets/send_to_pc_sheet.dart';
import 'models/batch_item_model.dart';
import 'notifiers/batch_notifier.dart';
import 'widgets/batch_empty_selection_card.dart';
import 'widgets/batch_estimator_banner.dart';
import 'widgets/batch_header_stats.dart';
import 'widgets/batch_image_card.dart';
import 'widgets/batch_image_preview_dialog.dart';
import 'widgets/batch_pdf_export_sheet.dart';
import 'widgets/batch_progress_card.dart';
import 'widgets/batch_results_view.dart';
import 'widgets/batch_selection_toolbar.dart';
import 'widgets/batch_settings_card.dart';

// Re-export BatchMode for any external files/tests referencing it from batch_screen.dart
export 'notifiers/batch_notifier.dart' show BatchMode;

class BatchScreen extends ConsumerStatefulWidget {
  final List<File>? initialImages;

  const BatchScreen({super.key, this.initialImages});

  @override
  ConsumerState<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends ConsumerState<BatchScreen> {
  late final TextEditingController _customSizeController;

  @override
  void initState() {
    super.initState();
    _customSizeController = TextEditingController(text: '100');
  }

  @override
  void dispose() {
    _customSizeController.dispose();
    super.dispose();
  }

  BatchNotifier get _notifier =>
      ref.read(batchNotifierProvider(widget.initialImages).notifier);

  Future<void> _handleCaptureFromScanner({bool append = false}) async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    try {
      final scannerService = DocumentScannerService();
      final scannedFiles = await scannerService.scanMultipleDocuments(
        pageLimit: 25,
      );

      if (scannedFiles.isNotEmpty) {
        _notifier.addFiles(scannedFiles, append: append);
        if (!mounted) return;
        final totalCount = ref
            .read(batchNotifierProvider(widget.initialImages))
            .items
            .length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📄 Scanned ${scannedFiles.length} document${scannedFiles.length > 1 ? "s" : ""} added ($totalCount total)',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on MissingPluginException catch (e) {
      debugPrint('[BatchScreen] MissingPluginException in smart scan: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Document scanner native plugin requires a full app restart. Please stop and re-run the app.',
          ),
          duration: Duration(seconds: 4),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      debugPrint('[BatchScreen] Error in smart scan: $e');
    }
  }

  Future<void> _handlePickFromGallery({bool append = false}) async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    try {
      final picker = ImagePicker();
      final pickedImages = await picker.pickMultiImage(limit: 50);
      if (pickedImages.isEmpty || !mounted) return;

      final files = pickedImages.map((x) => File(x.path)).toList();
      _notifier.addFiles(files, append: append);

      if (!mounted) return;
      final totalCount = ref
          .read(batchNotifierProvider(widget.initialImages))
          .items
          .length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📸 Added ${files.length} image${files.length > 1 ? "s" : ""} from gallery ($totalCount total)',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('[BatchScreen] Gallery pick error: $e');
    }
  }

  Future<void> _showAddSourceSheet({bool append = false}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  append ? 'Add More Images' : 'Select Images Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: isDark
                      ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                      : AppColors.surfaceVariantLight,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: Color(0xFF6366F1),
                      size: 24,
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Smart Document Scanner',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF6366F1,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ML KIT',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Multi-page camera scanner with auto boundary detection',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop('scanner'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: isDark
                      ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                      : AppColors.surfaceVariantLight,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  title: Text(
                    'Import from Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    'Select multiple photos from your device library',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop('gallery'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == 'scanner') {
      _handleCaptureFromScanner(append: append);
    } else if (choice == 'gallery') {
      _handlePickFromGallery(append: append);
    }
  }

  void _openPreview(BatchItemModel item, int index) {
    BatchImagePreviewDialog.show(
      context,
      item: item,
      onRemove: () => _notifier.removeItemAt(index),
      onCrop: () => _handleStudioEditItem(index),
      onCustomize: () => _notifier.setFocusedItem(item.path),
    );
  }

  Future<void> _handleStudioEditItem(int index) async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final batchState = ref.read(batchNotifierProvider(widget.initialImages));
    if (index >= batchState.items.length) return;
    final item = batchState.items[index];

    final File? editedFile = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => ImageStudioScreen(
          initialImage: item.file,
          returnResultDirectly: true,
          allowRePick: false,
        ),
      ),
    );

    if (editedFile != null && mounted) {
      final dims = await ImageProcessor.readImageDimensions(editedFile.path);
      var size = 0;
      try {
        if (editedFile.existsSync()) {
          size = editedFile.lengthSync();
        }
      } catch (_) {}

      _notifier.updateItemAt(
        index,
        item.copyWith(file: editedFile, fileSizeBytes: size, dimensions: dims),
      );

      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.fileName} updated from Studio!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleStartBatch() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    try {
      final result = await _notifier.processBatch();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Successfully processed ${result.results.length} images!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch processing error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleSaveAllToGallery(BatchState batchState) async {
    final batchResult = batchState.batchResult;
    if (batchResult == null) return;

    var savedCount = 0;
    for (final res in batchResult.results) {
      final ok = await StorageService.saveToGallery(res.outputPath);
      if (ok) savedCount++;
    }

    if (savedCount > 0) {
      HapticFeedback.lightImpact();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '💾 Saved $savedCount/${batchResult.results.length} images to Gallery!',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _handleShareZip(BatchState batchState) {
    final zip = batchState.batchResult?.zipFilePath;
    if (zip != null) {
      ShareService.shareImage(
        zip,
        text: 'Batch images compressed with Image Tools',
      );
    }
  }

  void _handleSendAllToPc(BatchState batchState) {
    final results = batchState.batchResult?.results;
    if (results == null || results.isEmpty) return;
    final filePaths = results.map((r) => r.outputPath).toList();
    SendToPcSheet.show(context, filePaths: filePaths);
  }

  void _handleExportAsPdf(BatchState batchState, {bool fromResults = true}) {
    List<File> filesToExport;
    if (fromResults &&
        batchState.batchResult != null &&
        batchState.batchResult!.results.isNotEmpty) {
      filesToExport = batchState.batchResult!.results
          .map((r) => File(r.outputPath))
          .toList();
    } else if (batchState.items.isNotEmpty) {
      filesToExport = batchState.items.map((it) => it.file).toList();
    } else {
      return;
    }

    BatchPdfExportSheet.show(context, imageFiles: filesToExport);
  }

  Future<void> _handleSaveSingleResult(ProcessResult result) async {
    final ok = await StorageService.saveToGallery(result.outputPath);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💾 Saved image to Gallery!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleShareSingleResult(ProcessResult result) {
    ShareService.shareImage(
      result.outputPath,
      text: 'Compressed with Image Tools',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = context.isMediumOrWider;
    final batchState = ref.watch(batchNotifierProvider(widget.initialImages));

    ref.listen<BatchState>(batchNotifierProvider(widget.initialImages), (
      previous,
      next,
    ) {
      final prevFocused = previous?.focusedItem;
      final nextFocused = next.focusedItem;
      if (previous?.focusedItemPath != next.focusedItemPath ||
          previous?.selectedPaths != next.selectedPaths ||
          prevFocused?.customOptions != nextFocused?.customOptions) {
        final size = nextFocused != null
            ? (nextFocused.customOptions?.targetSizeKB ??
                  next.selectedTargetSizeKB)
            : next.selectedTargetSizeKB;
        if (_customSizeController.text != size.toString()) {
          _customSizeController.text = size.toString();
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Processing'),
        actions: [
          if (batchState.items.isNotEmpty &&
              !batchState.isProcessing &&
              batchState.batchResult == null) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export Selected to PDF',
              onPressed: () =>
                  _handleExportAsPdf(batchState, fromResults: false),
            ),
            TextButton.icon(
              onPressed: _notifier.clearAll,
              icon: const Icon(
                Icons.clear_all_rounded,
                size: 18,
                color: AppColors.error,
              ),
              label: const Text(
                'Clear',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: batchState.items.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.adaptiveMargin,
                    vertical: 24,
                  ),
                  child: AdaptivePageContainer(
                    maxWidth: 600,
                    child: BatchEmptySelectionCard(
                      onSmartScannerPressed: () =>
                          _handleCaptureFromScanner(append: false),
                      onGalleryPressed: () =>
                          _handlePickFromGallery(append: false),
                    ),
                  ),
                ),
              )
            : isWide
            ? AdaptiveSupportingPane(
                scrollablePrimaryPane: true,
                stretchPrimaryPane: false,
                primaryFlex: 5,
                supportingFlex: 5,
                primaryPane: _buildSelectionPaneWide(isDark, batchState),
                supportingPane: _buildOptionsSection(isDark, batchState),
                bottomAction: batchState.batchResult == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BatchEstimatorBanner(
                            totalOriginalBytes: batchState.totalSelectedBytes,
                            estimatedOutputBytes:
                                batchState.estimatedTotalOutputBytes,
                            estimatedSavedBytes: batchState.estimatedSavedBytes,
                            estimatedSavedPercentage:
                                batchState.estimatedSavedPercentage,
                          ),
                          const SizedBox(height: 12),
                          GradientButton(
                            text:
                                '⚡ Start Batch Optimization (${batchState.items.length} Images)',
                            isLoading: batchState.isProcessing,
                            onPressed: batchState.isProcessing
                                ? null
                                : _handleStartBatch,
                          ),
                        ],
                      )
                    : null,
              )
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contextual Multi-Selection Toolbar (if 1 or more images selected)
                    if (batchState.hasSelection) ...[
                      BatchSelectionToolbar(
                        selectedCount: batchState.selectionCount,
                        totalCount: batchState.items.length,
                        isAllSelected: batchState.isAllSelected,
                        onToggleSelectAll: () {
                          if (batchState.isAllSelected) {
                            _notifier.deselectAll();
                          } else {
                            _notifier.selectAll();
                          }
                        },
                        onRemoveSelected: _notifier.removeSelectedItems,
                        onApplySettingsToSelected:
                            _notifier.applyCurrentSettingsToSelected,
                        onDeselectAll: _notifier.deselectAll,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 1. Selection Section
                    _buildSelectionStrip(isDark, batchState),
                    const SizedBox(height: 20),

                    // 2. Batch Processing Options
                    if (batchState.batchResult == null) ...[
                      _buildOptionsSection(isDark, batchState),
                      const SizedBox(height: 16),

                      // Live Estimated Savings Banner
                      BatchEstimatorBanner(
                        totalOriginalBytes: batchState.totalSelectedBytes,
                        estimatedOutputBytes:
                            batchState.estimatedTotalOutputBytes,
                        estimatedSavedBytes: batchState.estimatedSavedBytes,
                        estimatedSavedPercentage:
                            batchState.estimatedSavedPercentage,
                      ),
                      const SizedBox(height: 16),

                      // Start Processing Button
                      GradientButton(
                        text:
                            '⚡ Start Batch Optimization (${batchState.items.length} Images)',
                        isLoading: batchState.isProcessing,
                        onPressed: batchState.isProcessing
                            ? null
                            : _handleStartBatch,
                      ),
                    ],

                    // 3. Processing Progress
                    if (batchState.isProcessing &&
                        batchState.progress != null) ...[
                      const SizedBox(height: 24),
                      BatchProgressCard(
                        progress: batchState.progress!,
                        onCancel: _notifier.cancelCurrentBatch,
                      ),
                    ],

                    // 4. Batch Results View
                    if (batchState.batchResult != null) ...[
                      const SizedBox(height: 24),
                      BatchResultsView(
                        batchResult: batchState.batchResult!,
                        onSaveAllToGallery: () =>
                            _handleSaveAllToGallery(batchState),
                        onExportAsPdf: () =>
                            _handleExportAsPdf(batchState, fromResults: true),
                        onShareZip: () => _handleShareZip(batchState),
                        onSendAllToPc: () => _handleSendAllToPc(batchState),
                        onReProcess: _notifier.resetResult,
                        onRetryFailed: _notifier.retryFailedItems,
                        onSaveSingleResult: _handleSaveSingleResult,
                        onShareSingleResult: _handleShareSingleResult,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSelectionPaneWide(bool isDark, BatchState batchState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (batchState.hasSelection) ...[
          BatchSelectionToolbar(
            selectedCount: batchState.selectionCount,
            totalCount: batchState.items.length,
            isAllSelected: batchState.isAllSelected,
            onToggleSelectAll: () {
              if (batchState.isAllSelected) {
                _notifier.deselectAll();
              } else {
                _notifier.selectAll();
              }
            },
            onRemoveSelected: _notifier.removeSelectedItems,
            onApplySettingsToSelected: _notifier.applyCurrentSettingsToSelected,
            onDeselectAll: _notifier.deselectAll,
          ),
          const SizedBox(height: 14),
        ],

        BatchHeaderStats(
          itemCount: batchState.items.length,
          totalBytes: batchState.totalSelectedBytes,
          customizedCount: batchState.customizedItemCount,
          isProcessing: batchState.isProcessing,
          onScanMorePressed: () => _showAddSourceSheet(append: true),
          onResetAllOverrides: _notifier.resetAllCustomOverrides,
        ),
        const SizedBox(height: 16),

        // Grid of Batch Cards
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: batchState.items.length + 1,
          itemBuilder: (context, index) {
            if (index < batchState.items.length) {
              final item = batchState.items[index];
              return BatchImageCard(
                item: item,
                isSelected: batchState.selectedPaths.contains(item.path),
                isFocused: batchState.focusedItemPath == item.path,
                onToggleSelect: () => _notifier.toggleItemSelection(item.path),
                onTapFocus: () => _notifier.setFocusedItem(item.path),
                onRemove: () => _notifier.removeItemAt(index),
                onTapPreview: () => _openPreview(item, index),
                onTapCrop: () => _handleStudioEditItem(index),
              );
            }
            return _buildAddTile(isDark);
          },
        ),

        // Custom Override Banner displayed below image cards
        if (batchState.customizedItemCount > 0) ...[
          const SizedBox(height: 14),
          BatchCustomOverridesBanner(
            customizedCount: batchState.customizedItemCount,
            onResetAllOverrides: _notifier.resetAllCustomOverrides,
          ),
        ],

        // Processing Progress
        if (batchState.isProcessing && batchState.progress != null) ...[
          const SizedBox(height: 24),
          BatchProgressCard(
            progress: batchState.progress!,
            onCancel: _notifier.cancelCurrentBatch,
          ),
        ],

        // Batch Results View
        if (batchState.batchResult != null) ...[
          const SizedBox(height: 24),
          BatchResultsView(
            batchResult: batchState.batchResult!,
            onSaveAllToGallery: () => _handleSaveAllToGallery(batchState),
            onExportAsPdf: () =>
                _handleExportAsPdf(batchState, fromResults: true),
            onShareZip: () => _handleShareZip(batchState),
            onSendAllToPc: () => _handleSendAllToPc(batchState),
            onReProcess: _notifier.resetResult,
            onRetryFailed: _notifier.retryFailedItems,
            onSaveSingleResult: _handleSaveSingleResult,
            onShareSingleResult: _handleShareSingleResult,
          ),
        ],
      ],
    );
  }

  Widget _buildSelectionStrip(bool isDark, BatchState batchState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BatchHeaderStats(
          itemCount: batchState.items.length,
          totalBytes: batchState.totalSelectedBytes,
          customizedCount: batchState.customizedItemCount,
          isProcessing: batchState.isProcessing,
          onScanMorePressed: () => _showAddSourceSheet(append: true),
          onResetAllOverrides: _notifier.resetAllCustomOverrides,
        ),
        const SizedBox(height: 12),

        // Horizontal Images Strip with Drag-to-reorder support
        SizedBox(
          height: 195,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: batchState.items.length + 1,
            onReorderItem: (oldIndex, newIndex) {
              if (oldIndex < batchState.items.length &&
                  newIndex < batchState.items.length) {
                _notifier.reorderItems(
                  oldIndex,
                  oldIndex < newIndex ? newIndex + 1 : newIndex,
                );
              }
            },
            itemBuilder: (context, index) {
              if (index < batchState.items.length) {
                final item = batchState.items[index];
                return Padding(
                  key: ValueKey(item.path),
                  padding: const EdgeInsets.only(right: 12),
                  child: BatchImageCard(
                    item: item,
                    isSelected: batchState.selectedPaths.contains(item.path),
                    isFocused: batchState.focusedItemPath == item.path,
                    onToggleSelect: () =>
                        _notifier.toggleItemSelection(item.path),
                    onTapFocus: () => _notifier.setFocusedItem(item.path),
                    onRemove: () => _notifier.removeItemAt(index),
                    onTapPreview: () => _openPreview(item, index),
                    onTapCrop: () => _handleStudioEditItem(index),
                    dragHandle: ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.drag_indicator_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Padding(
                key: const ValueKey('add_tile_btn'),
                padding: const EdgeInsets.only(right: 12),
                child: _buildAddTile(isDark),
              );
            },
          ),
        ),

        // Custom Override Banner displayed below image cards
        if (batchState.customizedItemCount > 0) ...[
          const SizedBox(height: 14),
          BatchCustomOverridesBanner(
            customizedCount: batchState.customizedItemCount,
            onResetAllOverrides: _notifier.resetAllCustomOverrides,
          ),
        ],
      ],
    );
  }

  Widget _buildAddTile(bool isDark) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
            : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showAddSourceSheet(append: true),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF6366F1,
                ).withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                color: Color(0xFF6366F1),
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '+ Add Images',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Scanner / Gallery',
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSection(bool isDark, BatchState batchState) {
    final focused = batchState.focusedItem;
    final activeMode = focused?.customOptions != null
        ? (focused!.customOptions!.resizeMode == ResizeMode.percentage
              ? BatchMode.scalePercentage
              : BatchMode.targetSize)
        : batchState.activeMode;
    final targetSizeKB =
        focused?.customOptions?.targetSizeKB ?? batchState.selectedTargetSizeKB;
    final scalePercentage =
        focused?.customOptions?.resizePercentage ??
        batchState.selectedScalePercentage;
    final outputFormat =
        focused?.customOptions?.outputFormat ?? batchState.outputFormat;

    final selectedCount = batchState.selectionCount;

    return BatchSettingsCard(
      focusedItem: focused,
      selectedCount: selectedCount,
      onResetItemCustom: () {
        if (selectedCount > 0) {
          _notifier.resetSelectedItemsOptions();
        } else {
          _notifier.resetFocusedItemOptions();
        }
      },
      onCloseFocus: () {
        if (selectedCount > 0) {
          _notifier.deselectAll();
        } else {
          _notifier.clearFocusedItem();
        }
      },
      activeMode: activeMode,
      selectedTargetSizeKB: targetSizeKB,
      selectedScalePercentage: scalePercentage,
      outputFormat: outputFormat,
      customSizeController: _customSizeController,
      onModeChanged: _notifier.setActiveMode,
      onTargetSizeKBChanged: _notifier.setTargetSizeKB,
      onScalePercentageChanged: _notifier.setScalePercentage,
      onOutputFormatChanged: _notifier.setOutputFormat,
    );
  }
}
