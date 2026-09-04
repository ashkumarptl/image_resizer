import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/extensions/file_size_extension.dart';
import '../../data/models/process_options.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/usage_limit_repository.dart';
import '../../services/analytics_service.dart';
import '../../services/crashlytics_service.dart';
import '../../services/image_service/batch_processor.dart';
import '../../services/share_service.dart';
import '../../services/storage_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/login_gate_dialog.dart';
import '../widgets/send_to_pc_sheet.dart';

class BatchScreen extends ConsumerStatefulWidget {
  final List<File>? initialImages;

  const BatchScreen({super.key, this.initialImages});

  @override
  ConsumerState<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends ConsumerState<BatchScreen> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedFiles = [];
  bool _isProcessing = false;
  BatchProgress? _progress;
  BatchResult? _batchResult;

  int _selectedTargetSizeKB = 100;
  String _outputFormat = 'jpg';

  @override
  void initState() {
    super.initState();
    if (widget.initialImages != null && widget.initialImages!.isNotEmpty) {
      _selectedFiles = List.from(widget.initialImages!);
    }
  }

  Future<void> _handlePickImages() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final pickedList = await _picker.pickMultiImage();
    if (pickedList.isNotEmpty) {
      setState(() {
        _selectedFiles = pickedList.map((x) => File(x.path)).toList();
        _batchResult = null;
      });
    }
  }

  Future<void> _handleStartBatch() async {
    if (_selectedFiles.isEmpty) return;

    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    setState(() {
      _isProcessing = true;
      _batchResult = null;
    });

    final totalCount = _selectedFiles.length;
    await AnalyticsService.logBatchResizeStarted(count: totalCount);
    await CrashlyticsService.setProcessingContext(
      operation: 'batch_resize',
      inputWidth: 0,
      inputHeight: 0,
      inputSizeKb: 0,
      outputFormat: _outputFormat,
    );

    final baseOptions = ProcessOptions(
      sourcePath: '',
      targetSizeKB: _selectedTargetSizeKB,
      outputFormat: _outputFormat,
    );

    try {
      final result = await BatchProcessor.processBatch(
        sourceFilePaths: _selectedFiles.map((f) => f.path).toList(),
        baseOptions: baseOptions,
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

      // Increment guest usage count if user is not authenticated
      final user = ref.read(currentUserProvider);
      if (user == null) {
        await ref.read(guestUsageCountProvider.notifier).increment();
      }

      setState(() {
        _isProcessing = false;
        _batchResult = result;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Successfully processed ${result.results.length} images!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(e, stack, reason: 'Batch processing failure');
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💾 Saved $savedCount/${_batchResult!.results.length} images to Gallery!'),
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
    SendToPcSheet.show(
      context,
      filePaths: filePaths,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Processing'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 44,
                      color: _selectedFiles.isEmpty ? Colors.grey : AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _selectedFiles.isEmpty
                          ? 'No Images Selected'
                          : '${_selectedFiles.length} Images Selected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedFiles.isEmpty
                          ? 'Select 2 to 50 images to optimize simultaneously.'
                          : 'Ready for batch compression.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _handlePickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(_selectedFiles.isEmpty ? 'Select Images' : 'Change Selection'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_selectedFiles.isNotEmpty && _batchResult == null) ...[
                // Batch Options
                Text(
                  'Batch Target Size (Per Image)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 10),
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
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedTargetSizeKB = sizeKB);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Format
                Text(
                  'Target Format',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['jpg', 'webp', 'png'].map((fmt) {
                    final isSelected = _outputFormat == fmt;
                    return ChoiceChip(
                      label: Text(fmt.toUpperCase()),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      onSelected: (sel) {
                        if (sel) setState(() => _outputFormat = fmt);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // Start Button
                GradientButton(
                  text: '⚡ Start Batch Optimization (${_selectedFiles.length})',
                  isLoading: _isProcessing,
                  onPressed: _isProcessing ? null : _handleStartBatch,
                ),
              ],

              // Processing Progress Card
              if (_isProcessing && _progress != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Optimizing: ${_progress!.completed} / ${_progress!.total}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                      LinearProgressIndicator(
                        value: _progress!.percentage,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: isDark ? Colors.black38 : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _progress!.currentFileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Batch Results Summary
              if (_batchResult != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.success, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Batch Complete (${_batchResult!.results.length} Files)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Total Time: ${_batchResult!.totalDuration.inSeconds}s',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Results List Preview
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _batchResult!.results.length > 4 ? 4 : _batchResult!.results.length,
                        separatorBuilder: (_, _) => const Divider(height: 12),
                        itemBuilder: (context, idx) {
                          final item = _batchResult!.results[idx];
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Image #${idx + 1}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                '${item.originalSizeBytes.toReadableFileSize()} ➔ ${item.outputSizeBytes.toReadableFileSize()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                GradientButton(
                  text: '💾 Save All to Gallery',
                  icon: Icons.download_rounded,
                  onPressed: _handleSaveAllToGallery,
                ),
                const SizedBox(height: 12),

                if (_batchResult?.zipFilePath != null) ...[
                  SizedBox(
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
                  const SizedBox(height: 12),
                ],

                SizedBox(
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
              ],
              const SizedBox(height: 16),
              const SafeArea(
                top: false,
                child: SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
