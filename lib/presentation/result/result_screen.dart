import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/history_item.dart';
import '../../data/models/process_result.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/usage_limit_repository.dart';
import '../../services/analytics_service.dart';
import '../../services/share_service.dart';
import '../../services/storage_service.dart';
import '../../services/system_integration_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/send_to_pc_sheet.dart';
import 'widgets/before_after_card.dart';
import 'widgets/celebratory_savings_banner.dart';
import 'widgets/next_actions_section.dart';

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

    // Increment guest usage count if user is not authenticated and not developer
    final isDeveloper = ref.read(isDeveloperProvider);
    final user = ref.read(currentUserProvider);
    if (user == null && !isDeveloper) {
      await ref.read(guestUsageCountProvider.notifier).increment();
    }
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
      HapticFeedback.lightImpact();
      AnalyticsService.logImageSaved(
        outputFormat: widget.result.outputFormat,
        sizeKb: (widget.result.outputSizeBytes / 1024).round(),
        destination: 'gallery',
      );
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Image saved to Gallery successfully!'),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: _handleOpenInGallery,
          ),
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

  Future<void> _handleOpenInGallery() async {
    HapticFeedback.lightImpact();
    if (!_isSaved) {
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
    }
    final opened = await SystemIntegrationService.instance.openInGallery(
      widget.result.outputPath,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open gallery viewer. Image saved to photos!'),
        ),
      );
    }
  }

  Future<void> _handlePrint() async {
    HapticFeedback.lightImpact();
    final printed = await SystemIntegrationService.instance.printImage(
      widget.result.outputPath,
    );
    if (!printed && mounted) {
      // Fallback: Share to system print dialog or printer app
      ShareService.shareImage(widget.result.outputPath, text: 'Print Image');
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

  void _handleSendToPc() {
    SendToPcSheet.show(
      context,
      filePaths: [widget.result.outputPath],
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
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: _handlePrint,
          ),
          IconButton(
            icon: Badge(
              label: const Text(
                'PC',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: AppColors.secondary,
              child: const Icon(Icons.laptop_chromebook_rounded),
            ),
            tooltip: 'Send to PC (Cyber Cafe)',
            onPressed: _handleSendToPc,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share',
            onPressed: _handleShare,
          ),
        ],
      ),
      body: SafeArea(
        child: AdaptiveSupportingPane(
          requireLandscape: true,
          maxStackedContentWidth: 700,
          stretchPrimaryPane: false,
          scrollablePrimaryPane: true,
          primaryFlex: 6,
          supportingFlex: 5,
          primaryPane: _buildInspectionSection(result, isDark),
          supportingPane: _buildActionsSection(isDark),
        ),
      ),
    );
  }

  Widget _buildInspectionSection(ProcessResult result, bool isDark) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CelebratorySavingsBanner(result: result),
          BeforeAfterCard(result: result),
          const SizedBox(height: 10),
          _buildSpecGrid(result, isDark),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildSpecGrid(ProcessResult result, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SpecTile(
                  label: 'Output Dimensions',
                  value: '${result.outputWidth} × ${result.outputHeight} px',
                  subValue: '(${result.originalWidth}×${result.originalHeight})',
                  isDark: isDark,
                ),
              ),
              Container(
                height: 30,
                width: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _SpecTile(
                    label: 'Format',
                    value: result.outputFormat.toUpperCase(),
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
          Divider(
            height: 12,
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          Row(
            children: [
              Expanded(
                child: _SpecTile(
                  label: 'Quality Applied',
                  value: '${result.finalQuality}%',
                  isDark: isDark,
                ),
              ),
              Container(
                height: 30,
                width: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _SpecTile(
                    label: 'Processing Time',
                    value: '${result.processingTime.inMilliseconds} ms',
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
          if (result.metadataStripped) ...[
            Divider(
              height: 12,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'GPS & Camera metadata stripped for privacy',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionsSection(bool isDark) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary Action Button
          Builder(
            builder: (context) {
              if (!_isSaved) {
                return GradientButton(
                  text: 'Save to Gallery',
                  icon: Icons.download_rounded,
                  isLoading: _isSaving,
                  onPressed: _handleSaveToGallery,
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(23),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16)
                                  .animate()
                                  .scale(delay: 100.ms, duration: 250.ms, curve: Curves.easeOutBack),
                              const SizedBox(width: 4),
                              const Flexible(
                                child: Text(
                                  'Saved ✓',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 250.ms)
                        .scale(begin: const Offset(0.88, 0.88), end: const Offset(1, 1), curve: Curves.easeOutBack),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _handleOpenInGallery,
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text(
                          'Open in Gallery',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Secondary Action Row (Direct Print, Share & Send to PC)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _handlePrint,
                    icon: const Icon(Icons.print_outlined, size: 17),
                    label: const Text('Print', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _handleShare,
                    icon: const Icon(Icons.share_outlined, size: 17),
                    label: const Text('Share', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox.expand(
                        child: OutlinedButton.icon(
                          onPressed: _handleSendToPc,
                          icon: const Icon(Icons.laptop_chromebook_rounded, size: 18),
                          label: const Text(
                            'Send to PC',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            backgroundColor: AppColors.primary.withValues(alpha: 0.04),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -7,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D9488), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, size: 9, color: Colors.white),
                              SizedBox(width: 2),
                              Text(
                                'CYBER CAFE / PC',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Slim Cyber Cafe & Form Fillers Hint Card
          InkWell(
            onTap: _handleSendToPc,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.laptop_chromebook_rounded,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filling a form on PC? Transfer wirelessly without WhatsApp or cable.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF115E59),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: AppColors.secondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Smart Next Actions Suggestions
          const NextActionsSection(),
          const SizedBox(height: 8),

          // Process Another Image Button
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text('Process Another Image', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 60.ms, duration: 250.ms)
        .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
  }
}

class _SpecTile extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final bool isDark;

  const _SpecTile({
    required this.label,
    required this.value,
    this.subValue,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (subValue != null) ...[
              const SizedBox(width: 4),
              Text(
                subValue!,
                style: TextStyle(
                  fontSize: 10.5,
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
