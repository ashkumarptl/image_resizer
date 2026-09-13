import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/extensions/file_size_extension.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/process_options.dart';
import '../../data/models/process_result.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/usage_limit_repository.dart';
import '../../services/analytics_service.dart';
import '../../services/crashlytics_service.dart';
import '../../services/image_service/batch_processor.dart';
import '../../services/image_service/image_processor.dart';
import '../../services/share_service.dart';
import '../../services/storage_service.dart';
import '../../services/scanner/document_scanner_service.dart';
import '../studio/image_studio_screen.dart';
import '../widgets/bouncy_tap.dart';
import '../widgets/gradient_button.dart';
import '../widgets/login_gate_dialog.dart';
import '../widgets/send_to_pc_sheet.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'models/batch_item_model.dart';
import 'widgets/batch_image_card.dart';
import 'widgets/batch_image_preview_dialog.dart';
import 'widgets/batch_item_settings_sheet.dart';
import 'widgets/batch_pdf_export_sheet.dart';

enum BatchMode { targetSize, scalePercentage }

class BatchScreen extends ConsumerStatefulWidget {
  final List<File>? initialImages;

  const BatchScreen({super.key, this.initialImages});

  @override
  ConsumerState<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends ConsumerState<BatchScreen> {
  final List<BatchItemModel> _items = [];
  bool _isProcessing = false;
  BatchProgress? _progress;
  BatchResult? _batchResult;

  // Processing Settings
  BatchMode _activeMode = BatchMode.targetSize;
  int _selectedTargetSizeKB = 100;
  int _selectedScalePercentage = 100;
  String _outputFormat = 'jpg';
  late final TextEditingController _customSizeController;

  @override
  void initState() {
    super.initState();
    _customSizeController = TextEditingController(
      text: '$_selectedTargetSizeKB',
    );
    if (widget.initialImages != null && widget.initialImages!.isNotEmpty) {
      final initialItems = widget.initialImages!
          .map((f) => BatchItemModel.fromFile(f))
          .toList();
      _items.addAll(initialItems);
      _loadDimensionsForItems(initialItems);
    }
  }

  @override
  void dispose() {
    _customSizeController.dispose();
    super.dispose();
  }

  int get _totalSelectedBytes =>
      _items.fold(0, (sum, it) => sum + it.fileSizeBytes);
  int get _customizedItemCount =>
      _items.where((it) => it.hasCustomOptions).length;

  Future<void> _loadDimensionsForItems(List<BatchItemModel> itemsToLoad) async {
    for (final item in itemsToLoad) {
      final dims = await ImageProcessor.readImageDimensions(item.path);
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((it) => it.path == item.path);
        if (index != -1) {
          _items[index] = _items[index].copyWith(dimensions: dims);
        }
      });
    }
  }

  Future<void> _handleCaptureFromScanner({bool append = false}) async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    try {
      final scannerService = DocumentScannerService();
      final scannedFiles = await scannerService.scanMultipleDocuments(
        pageLimit: 25,
      );

      if (scannedFiles.isNotEmpty) {
        final newItems = scannedFiles
            .map((file) => BatchItemModel.fromFile(file))
            .toList();
        setState(() {
          if (!append) {
            _items.clear();
          }
          _items.addAll(newItems);
          _batchResult = null;
        });
        _loadDimensionsForItems(newItems);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📄 Scanned ${newItems.length} document${newItems.length > 1 ? "s" : ""} added (${_items.length} total)',
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

      final newItems = pickedImages
          .map((x) => BatchItemModel.fromFile(File(x.path)))
          .toList();

      setState(() {
        if (!append) {
          _items.clear();
        }
        _items.addAll(newItems);
        _batchResult = null;
      });
      _loadDimensionsForItems(newItems);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📸 Added ${newItems.length} image${newItems.length > 1 ? "s" : ""} from gallery (${_items.length} total)',
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

  void _handleRemoveItem(int index) {
    if (index >= 0 && index < _items.length) {
      setState(() {
        _items.removeAt(index);
        if (_items.isEmpty) {
          _batchResult = null;
        }
      });
    }
  }

  void _handleClearAll() {
    setState(() {
      _items.clear();
      _batchResult = null;
    });
  }

  void _openPreview(BatchItemModel item, int index) {
    BatchImagePreviewDialog.show(
      context,
      item: item,
      onRemove: () => _handleRemoveItem(index),
      onCrop: () => _handleStudioEditItem(index),
      onCustomize: () => _openItemCustomization(item, index),
    );
  }

  Future<void> _handleStudioEditItem(int index) async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final item = _items[index];
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

      if (!mounted) return;

      setState(() {
        _items[index] = item.copyWith(
          file: editedFile,
          fileSizeBytes: size,
          dimensions: dims,
        );
      });

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.fileName} updated from Studio!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  ProcessOptions _createBaseOptions() {
    return ProcessOptions(
      sourcePath: '',
      targetSizeKB: _activeMode == BatchMode.targetSize
          ? _selectedTargetSizeKB
          : null,
      outputFormat: _outputFormat,
      resizeMode:
          _activeMode == BatchMode.scalePercentage &&
              _selectedScalePercentage != 100
          ? ResizeMode.percentage
          : ResizeMode.none,
      resizePercentage:
          _activeMode == BatchMode.scalePercentage &&
              _selectedScalePercentage != 100
          ? _selectedScalePercentage
          : null,
      preventSizeIncrease: true,
    );
  }

  void _openItemCustomization(BatchItemModel item, int index) {
    final baseOptions = _createBaseOptions().copyWith(sourcePath: item.path);
    BatchItemSettingsSheet.show(
      context,
      item: item,
      defaultOptions: baseOptions,
      onSave: (customOpts) {
        setState(() {
          if (customOpts != null) {
            _items[index] = _items[index].copyWith(customOptions: customOpts);
          } else {
            _items[index] = _items[index].copyWith(clearCustomOptions: true);
          }
        });
      },
    );
  }

  void _resetAllCustomOverrides() {
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(clearCustomOptions: true);
      }
    });
  }

  Future<void> _handleStartBatch() async {
    if (_items.isEmpty) return;

    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    setState(() {
      _isProcessing = true;
      _batchResult = null;
    });

    final totalCount = _items.length;
    await AnalyticsService.logBatchResizeStarted(count: totalCount);
    await CrashlyticsService.setProcessingContext(
      operation: 'batch_resize',
      inputWidth: 0,
      inputHeight: 0,
      inputSizeKb: 0,
      outputFormat: _outputFormat,
    );

    final baseOptions = _createBaseOptions();
    final overrides = <String, ProcessOptions>{};
    for (final it in _items) {
      if (it.customOptions != null) {
        overrides[it.path] = it.customOptions!;
      }
    }

    try {
      final result = await BatchProcessor.processBatch(
        sourceFilePaths: _items.map((f) => f.path).toList(),
        baseOptions: baseOptions,
        itemOverrides: overrides.isNotEmpty ? overrides : null,
        createZip: true,
        onProgress: (prog) {
          setState(() {
            _progress = prog;
          });
        },
      );

      AnalyticsService.logBatchResizeCompleted(
        totalImages: totalCount,
        successCount: result.results.length,
        failedCount: totalCount - result.results.length,
        durationMs: result.totalDuration.inMilliseconds,
      );
      await CrashlyticsService.clearProcessingContext();

      // Increment guest usage count if user is not authenticated and not developer
      final isDeveloper = ref.read(isDeveloperProvider);
      final user = ref.read(currentUserProvider);
      if (user == null && !isDeveloper) {
        await ref.read(guestUsageCountProvider.notifier).increment();
      }

      setState(() {
        _isProcessing = false;
        _batchResult = result;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Successfully processed ${result.results.length} images!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(
        e,
        stack,
        reason: 'Batch processing failure',
      );
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch processing error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleSaveAllToGallery() async {
    if (_batchResult == null) return;

    var savedCount = 0;
    for (final res in _batchResult!.results) {
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
          '💾 Saved $savedCount/${_batchResult!.results.length} images to Gallery!',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _handleShareZip() {
    if (_batchResult?.zipFilePath != null) {
      ShareService.shareImage(
        _batchResult!.zipFilePath!,
        text: 'Batch images compressed with Image Tools',
      );
    }
  }

  void _handleSendAllToPc() {
    if (_batchResult == null || _batchResult!.results.isEmpty) return;
    final filePaths = _batchResult!.results.map((r) => r.outputPath).toList();
    SendToPcSheet.show(context, filePaths: filePaths);
  }

  void _handleExportAsPdf({bool fromResults = true}) {
    List<File> filesToExport;
    if (fromResults &&
        _batchResult != null &&
        _batchResult!.results.isNotEmpty) {
      filesToExport = _batchResult!.results
          .map((r) => File(r.outputPath))
          .toList();
    } else if (_items.isNotEmpty) {
      filesToExport = _items.map((it) => it.file).toList();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Processing'),
        actions: [
          if (_items.isNotEmpty && !_isProcessing && _batchResult == null) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export Selected to PDF',
              onPressed: () => _handleExportAsPdf(fromResults: false),
            ),
            TextButton.icon(
              onPressed: _handleClearAll,
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
        child: _items.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.adaptiveMargin,
                    vertical: 24,
                  ),
                  child: AdaptivePageContainer(
                    maxWidth: 600,
                    child: _buildEmptySelectionCard(isDark),
                  ),
                ),
              )
            : isWide
            ? AdaptiveSupportingPane(
                scrollablePrimaryPane: true,
                stretchPrimaryPane: false,
                primaryFlex: 5,
                supportingFlex: 5,
                primaryPane: _buildSelectionPaneWide(isDark),
                supportingPane: _buildOptionsSection(isDark),
                bottomAction: _batchResult == null
                    ? GradientButton(
                        text:
                            '⚡ Start Batch Optimization (${_items.length} Images)',
                        isLoading: _isProcessing,
                        onPressed: _isProcessing ? null : _handleStartBatch,
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
                    // 1. Selection Section
                    _buildSelectionStrip(isDark),
                    const SizedBox(height: 20),

                    // 2. Batch Processing Options (shown when items are selected and not yet completed)
                    if (_batchResult == null) ...[
                      _buildOptionsSection(isDark),
                      const SizedBox(height: 24),

                      // Start Processing Button
                      GradientButton(
                        text:
                            '⚡ Start Batch Optimization (${_items.length} Images)',
                        isLoading: _isProcessing,
                        onPressed: _isProcessing ? null : _handleStartBatch,
                      ),
                    ],

                    // 3. Processing Progress
                    if (_isProcessing && _progress != null) ...[
                      const SizedBox(height: 24),
                      _buildProgressCard(isDark),
                    ],

                    // 4. Batch Results View
                    if (_batchResult != null) ...[
                      const SizedBox(height: 24),
                      _buildResultsView(isDark),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSelectionPaneWide(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_items.length} Images Selected',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'Total: ${_totalSelectedBytes.toReadableFileSize()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isProcessing
                  ? null
                  : () => _showAddSourceSheet(append: true),
              icon: const Icon(Icons.document_scanner_rounded, size: 16),
              label: const Text('+ Scan More'),
            ),
          ],
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
          itemCount: _items.length + 1,
          itemBuilder: (context, index) {
            if (index < _items.length) {
              final item = _items[index];
              return BatchImageCard(
                item: item,
                onRemove: () => _handleRemoveItem(index),
                onTapPreview: () => _openPreview(item, index),
                onTapCrop: () => _handleStudioEditItem(index),
                onCustomize: () => _openItemCustomization(item, index),
              );
            }
            return _buildAddTile(isDark);
          },
        ),

        // Custom Override notice banner
        if (_customizedItemCount > 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainerDark.withValues(
                alpha: isDark ? 0.3 : 0.15,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$_customizedItemCount image${_customizedItemCount > 1 ? 's have' : ' has'} individual custom settings override.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Processing Progress
        if (_isProcessing && _progress != null) ...[
          const SizedBox(height: 24),
          _buildProgressCard(isDark),
        ],

        // Batch Results View
        if (_batchResult != null) ...[
          const SizedBox(height: 24),
          _buildResultsView(isDark),
        ],
      ],
    );
  }

  Widget _buildEmptySelectionCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryContainerLight.withValues(
                alpha: isDark ? 0.2 : 0.6,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              size: 38,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Multiple Images',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose up to 50 photos to compress, resize, and convert in bulk.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _handleCaptureFromScanner(append: false),
                  icon: const Icon(Icons.document_scanner_rounded, size: 20),
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Smart Document Scanner',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'ML KIT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    foregroundColor: isDark
                        ? Colors.white
                        : AppColors.textPrimaryLight,
                    side: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFF6366F1).withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _handlePickFromGallery(append: false),
                  icon: const Icon(
                    Icons.photo_library_rounded,
                    size: 20,
                    color: Color(0xFF6366F1),
                  ),
                  label: const Text(
                    'Import from Gallery',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionStrip(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_items.length} Images Selected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Total: ${_totalSelectedBytes.toReadableFileSize()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isProcessing
                  ? null
                  : () => _showAddSourceSheet(append: true),
              icon: const Icon(Icons.document_scanner_rounded, size: 16),
              label: const Text('+ Scan More'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Images Strip
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _items.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index < _items.length) {
                final item = _items[index];
                return BatchImageCard(
                  item: item,
                  onRemove: () => _handleRemoveItem(index),
                  onTapPreview: () => _openPreview(item, index),
                  onTapCrop: () => _handleStudioEditItem(index),
                  onCustomize: () => _openItemCustomization(item, index),
                );
              }
              return _buildAddTile(isDark);
            },
          ),
        ),

        // Custom Override notice banner
        if (_customizedItemCount > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainerDark.withValues(
                alpha: isDark ? 0.3 : 0.15,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_customizedItemCount item(s) have custom settings applied.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _resetAllCustomOverrides,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Reset All',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
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

  Widget _buildOptionsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.settings_suggest_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Default Batch Settings',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Segmented Button: Target Size vs Scale %
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<BatchMode>(
              segments: const [
                ButtonSegment<BatchMode>(
                  value: BatchMode.targetSize,
                  label: Text('Target Size (KB)'),
                  icon: Icon(Icons.compress_rounded, size: 16),
                ),
                ButtonSegment<BatchMode>(
                  value: BatchMode.scalePercentage,
                  label: Text('Scale Dimensions'),
                  icon: Icon(Icons.aspect_ratio_rounded, size: 16),
                ),
              ],
              selected: {_activeMode},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _activeMode = newSelection.first;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Sub-options depending on mode
          if (_activeMode == BatchMode.targetSize) ...[
            Text(
              'Preset Target Size (Per Image)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.defaultTargetSizesKB.map((sizeKB) {
                final isSelected = _selectedTargetSizeKB == sizeKB;
                return ChoiceChip(
                  label: Text('$sizeKB KB'),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  onSelected: (sel) {
                    if (sel) {
                      setState(() {
                        _selectedTargetSizeKB = sizeKB;
                        _customSizeController.text = sizeKB.toString();
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Custom KB input field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customSizeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Custom Target Size',
                      hintText: 'e.g. 75 or 250',
                      isDense: true,
                      suffixText: 'KB',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 5 && parsed <= 50000) {
                        setState(() {
                          _selectedTargetSizeKB = parsed;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Resize Dimensions (% of original)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [100, 75, 50, 25].map((pct) {
                final isSelected = _selectedScalePercentage == pct;
                return ChoiceChip(
                  label: Text('$pct%'),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _selectedScalePercentage = pct);
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),

          // Output Format
          Text(
            'Target Format',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children:
                [
                  ('jpg', 'JPG (Universal)'),
                  ('webp', 'WEBP (Compact)'),
                  ('png', 'PNG (Sharp)'),
                ].map((entry) {
                  final isSelected = _outputFormat == entry.$1;
                  return ChoiceChip(
                    label: Text(entry.$2),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _outputFormat = entry.$1);
                    },
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isDark) {
    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Optimizing: ${_progress!.completed} / ${_progress!.total}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${(_progress!.percentage * 100).toInt()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LinearProgressIndicator(
                          value: _progress!.percentage,
                          backgroundColor: isDark
                              ? Colors.black38
                              : Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                        if (_progress!.percentage > 0.05)
                          Positioned.fill(
                            child:
                                Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    )
                                    .animate(onPlay: (c) => c.repeat())
                                    .slideX(
                                      begin: -1.0,
                                      end: 1.0,
                                      duration: 1200.ms,
                                      curve: Curves.easeInOut,
                                    ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _progress!.currentFileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildResultsView(bool isDark) {
    final results = _batchResult!.results;
    final totalOrigBytes = results.fold<int>(
      0,
      (sum, r) => sum + r.originalSizeBytes,
    );
    final totalOutBytes = results.fold<int>(
      0,
      (sum, r) => sum + r.outputSizeBytes,
    );
    final savedBytes = totalOrigBytes - totalOutBytes;
    final savedPct = totalOrigBytes > 0
        ? (savedBytes / totalOrigBytes * 100).clamp(0, 100)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Header Card
        Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 24,
                      ).animate().scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1, 1),
                        curve: Curves.easeOutBack,
                        duration: 350.ms,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Batch Complete (${results.length} Files)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '-${savedPct.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                          .animate()
                          .scale(delay: 150.ms, curve: Curves.easeOutBack)
                          .shimmer(delay: 500.ms, duration: 1200.ms),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Size: ${totalOrigBytes.toReadableFileSize()} ➔ ${totalOutBytes.toReadableFileSize()}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        'Time: ${_batchResult!.totalDuration.inSeconds}s',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Individual Results List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (context, idx) {
                      final item = results[idx];
                      return Row(
                        children: [
                          // Thumbnail of processed image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(item.outputPath),
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              cacheWidth: 100,
                              errorBuilder: (_, _, _) => Container(
                                width: 44,
                                height: 44,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Text details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Image #${idx + 1} (${item.outputFormat.toUpperCase()})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.originalSizeBytes.toReadableFileSize()} ➔ ${item.outputSizeBytes.toReadableFileSize()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Action icons
                          IconButton(
                            icon: const Icon(
                              Icons.fullscreen_rounded,
                              size: 20,
                            ),
                            tooltip: 'Preview',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              final batchItem = BatchItemModel.fromFile(
                                File(item.outputPath),
                              );
                              BatchImagePreviewDialog.show(
                                context,
                                item: batchItem,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.save_alt_rounded, size: 20),
                            tooltip: 'Save to Gallery',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _handleSaveSingleResult(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined, size: 20),
                            tooltip: 'Share',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _handleShareSingleResult(item),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: 20),

        // Bulk Actions
        GradientButton(
          text: '💾 Save All to Gallery',
          icon: Icons.download_rounded,
          onPressed: _handleSaveAllToGallery,
        ),
        const SizedBox(height: 12),

        BouncyTap(
          pressedScale: 0.97,
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _handleExportAsPdf(fromResults: true),
              icon: const Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.primary,
              ),
              label: const Text(
                '📄 Export / Save as PDF Document',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_batchResult?.zipFilePath != null) ...[
          BouncyTap(
            pressedScale: 0.97,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _handleShareZip,
                icon: const Icon(Icons.folder_zip_outlined),
                label: const Text('Share ZIP Archive'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        BouncyTap(
          pressedScale: 0.97,
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _handleSendAllToPc,
              icon: const Icon(Icons.laptop_chromebook_rounded),
              label: const Text('Send All to PC (Wi-Fi Share)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Reset / Process another batch
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _batchResult = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Adjust Settings & Re-process'),
          ),
        ),
      ],
    );
  }
}
