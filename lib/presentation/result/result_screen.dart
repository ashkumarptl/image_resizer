import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/history_item.dart';
import '../../data/models/process_result.dart';
import '../../data/repositories/history_repository.dart';
import '../../services/analytics_service.dart';
import '../../services/share_service.dart';
import '../../services/storage_service.dart';
import '../widgets/gradient_button.dart';
import 'widgets/before_after_card.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final ProcessResult result;

  const ResultScreen({
    super.key,
    required this.result,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _saveToHistory();
  }

  Future<void> _saveToHistory() async {
    final historyItem = HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filePath: widget.result.outputPath,
      originalPath: widget.result.originalPath,
      originalSizeBytes: widget.result.originalSizeBytes,
      outputSizeBytes: widget.result.outputSizeBytes,
      width: widget.result.outputWidth,
      height: widget.result.outputHeight,
      format: widget.result.outputFormat,
      processedAt: DateTime.now(),
    );
    await ref.read(historyRepositoryProvider).addHistoryItem(historyItem);
  }

  Future<void> _handleSaveToGallery() async {
    if (_isSaved) return;

    setState(() => _isSaving = true);
    final success = await StorageService.saveToGallery(widget.result.outputPath);
    setState(() {
      _isSaving = false;
      _isSaved = success;
    });

    if (success) {
      AnalyticsService.logImageSaved(
        outputFormat: widget.result.outputFormat,
        sizeKb: (widget.result.outputSizeBytes / 1024).round(),
        destination: 'gallery',
      );
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Image saved to Gallery successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Could not save image. Please grant permission.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleShare() {
    AnalyticsService.logImageShared(
      outputFormat: widget.result.outputFormat,
      sizeKb: (widget.result.outputSizeBytes / 1024).round(),
    );
    ShareService.shareImage(
      widget.result.outputPath,
      text: 'Resized with Image Tools',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = widget.result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimization Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share',
            onPressed: _handleShare,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Before/After Comparison Card
              BeforeAfterCard(result: result),
              const SizedBox(height: 20),

              // Specs & Metadata Table
              Container(
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
                    _SpecRow(
                      label: 'Output Dimensions',
                      value: '${result.outputWidth} × ${result.outputHeight} px',
                      subValue: '(${result.originalWidth} × ${result.originalHeight})',
                    ),
                    const Divider(height: 20),
                    _SpecRow(
                      label: 'Format',
                      value: result.outputFormat.toUpperCase(),
                    ),
                    const Divider(height: 20),
                    _SpecRow(
                      label: 'Quality Applied',
                      value: '${result.finalQuality}%',
                    ),
                    const Divider(height: 20),
                    _SpecRow(
                      label: 'Processing Time',
                      value: '${result.processingTime.inMilliseconds} ms',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              GradientButton(
                text: _isSaved ? 'Saved to Gallery ✓' : 'Save to Gallery',
                icon: _isSaved ? Icons.check_circle : Icons.download_rounded,
                isLoading: _isSaving,
                onPressed: _isSaved ? null : _handleSaveToGallery,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _handleShare,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share Image'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Process Another Image'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;

  const _SpecRow({
    required this.label,
    required this.value,
    this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            if (subValue != null) ...[
              const SizedBox(width: 4),
              Text(
                subValue!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
