import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/analytics_service.dart';
import '../../../services/crashlytics_service.dart';
import '../../../services/scanner/document_scanner_service.dart';
import '../../../services/share_service.dart';
import '../../../services/storage_service.dart';
import '../../widgets/bouncy_tap.dart';
import '../../widgets/gradient_button.dart';

/// Modal bottom sheet to customize and export batch images into a single multi-page PDF document
class BatchPdfExportSheet extends StatefulWidget {
  final List<File> imageFiles;
  final String? defaultFileName;

  const BatchPdfExportSheet({
    super.key,
    required this.imageFiles,
    this.defaultFileName,
  });

  static Future<void> show(
    BuildContext context, {
    required List<File> imageFiles,
    String? defaultFileName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BatchPdfExportSheet(
        imageFiles: imageFiles,
        defaultFileName: defaultFileName,
      ),
    );
  }

  @override
  State<BatchPdfExportSheet> createState() => _BatchPdfExportSheetState();
}

class _BatchPdfExportSheetState extends State<BatchPdfExportSheet> {
  late final TextEditingController _fileNameController;
  PdfQualityPreset _selectedQuality = PdfQualityPreset.medium;
  bool _isSaving = false;
  bool _isSharing = false;
  File? _cachedPdf;
  PdfQualityPreset? _cachedQuality;

  @override
  void initState() {
    super.initState();
    final timeStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final initialName = widget.defaultFileName ?? 'ImageTools_Batch_$timeStr';
    _fileNameController = TextEditingController(
      text: initialName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
    );
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  String get _sanitizedFileName {
    var raw = _fileNameController.text.trim();
    if (raw.isEmpty) {
      raw = 'ImageTools_Batch_${DateTime.now().millisecondsSinceEpoch}';
    }
    // Remove illegal file name characters
    raw = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (!raw.toLowerCase().endsWith('.pdf')) {
      raw = '$raw.pdf';
    }
    return raw;
  }

  Future<File?> _ensurePdfGenerated() async {
    if (_cachedPdf != null &&
        _cachedQuality == _selectedQuality &&
        await _cachedPdf!.exists()) {
      return _cachedPdf;
    }

    final pdf = await DocumentScannerService.createPdfFromImages(
      widget.imageFiles,
      outputFileName: _sanitizedFileName,
      qualityPreset: _selectedQuality,
    );

    _cachedPdf = pdf;
    _cachedQuality = _selectedQuality;
    return pdf;
  }

  Future<void> _handleSaveToDevice() async {
    if (_isSaving || _isSharing) return;

    setState(() => _isSaving = true);
    try {
      final pdf = await _ensurePdfGenerated();
      if (pdf == null || !mounted) return;

      final savedFile = await StorageService.savePdfToDevice(
        pdf.path,
        customFileName: _sanitizedFileName,
      );

      if (!mounted) return;

      if (savedFile != null) {
        HapticFeedback.lightImpact();
        AnalyticsService.logBatchExportPdf(
          pageCount: widget.imageFiles.length,
          quality: _selectedQuality.name,
          action: 'save_to_device',
        );

        final fileName = _sanitizedFileName;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();

        messenger.showSnackBar(
          SnackBar(
            content: Text('📄 Saved $fileName to Downloads!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () {
                ShareService.shareImage(
                  savedFile.path,
                  text: 'PDF document generated with Image Tools',
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save PDF to device storage'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(e, stack, reason: 'Batch PDF export save failure');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleSharePdf() async {
    if (_isSaving || _isSharing) return;

    setState(() => _isSharing = true);
    try {
      final pdf = await _ensurePdfGenerated();
      if (pdf == null || !mounted) return;

      AnalyticsService.logBatchExportPdf(
        pageCount: widget.imageFiles.length,
        quality: _selectedQuality.name,
        action: 'share',
      );

      final pdfPath = pdf.path;
      if (mounted) {
        Navigator.of(context).pop();
      }

      await ShareService.shareImage(
        pdfPath,
        text: 'PDF document generated with Image Tools (${widget.imageFiles.length} pages)',
      );
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(e, stack, reason: 'Batch PDF export share failure');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 24 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export as PDF Document',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.imageFiles.length} page${widget.imageFiles.length > 1 ? "s" : ""} will be merged into one file',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // File Name Input
            Text(
              'PDF File Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fileNameController,
              enabled: !_isSaving && !_isSharing,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.description_outlined, size: 20),
                suffixText: '.pdf',
                suffixStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Enter file name',
              ),
            ),
            const SizedBox(height: 20),

            // Quality Presets
            Row(
              children: [
                Text(
                  'Document Quality',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const Spacer(),
                Text(
                  _selectedQuality.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PdfQualityPreset.values.map((preset) {
                final isSelected = _selectedQuality == preset;
                return ChoiceChip(
                  label: Text(preset.label.split(' (').first),
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
                  onSelected: (_isSaving || _isSharing)
                      ? null
                      : (sel) {
                          if (sel) {
                            setState(() {
                              _selectedQuality = preset;
                            });
                          }
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedQuality.subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            GradientButton(
              text: _isSaving ? 'Compiling & Saving...' : '💾 Save to Downloads',
              icon: Icons.download_rounded,
              isLoading: _isSaving,
              onPressed: (_isSaving || _isSharing) ? null : _handleSaveToDevice,
            ),
            const SizedBox(height: 12),

            BouncyTap(
              pressedScale: 0.97,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: (_isSaving || _isSharing) ? null : _handleSharePdf,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_rounded),
                  label: Text(_isSharing ? 'Preparing PDF...' : 'Share PDF Document'),
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
          ],
        ),
      ),
    );
  }
}
