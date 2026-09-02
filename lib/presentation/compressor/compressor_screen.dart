import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/extensions/file_size_extension.dart';
import '../../data/models/process_options.dart';
import '../../services/analytics_service.dart';
import '../../services/crashlytics_service.dart';
import '../../services/image_service/image_processor.dart';
import '../result/result_screen.dart';
import '../widgets/gradient_button.dart';

class CompressorScreen extends StatefulWidget {
  final File initialImage;
  final int? prefilledTargetSizeKB;
  final String? presetTitle;

  const CompressorScreen({
    super.key,
    required this.initialImage,
    this.prefilledTargetSizeKB,
    this.presetTitle,
  });

  @override
  State<CompressorScreen> createState() => _CompressorScreenState();
}

class _CompressorScreenState extends State<CompressorScreen> {
  late TextEditingController _targetSizeController;
  int _selectedTargetSizeKB = 50;
  String _outputFormat = 'jpg';
  bool _isProcessing = false;
  int _fileSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _fileSizeBytes = widget.initialImage.lengthSync();
    _selectedTargetSizeKB = widget.prefilledTargetSizeKB ?? 50;
    _targetSizeController = TextEditingController(text: _selectedTargetSizeKB.toString());
  }

  @override
  void dispose() {
    _targetSizeController.dispose();
    super.dispose();
  }

  Future<void> _handleCompress() async {
    final targetKB = int.tryParse(_targetSizeController.text.trim());
    if (targetKB == null || targetKB <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target size (KB)')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    await CrashlyticsService.setProcessingContext(
      operation: 'compress',
      inputWidth: 0,
      inputHeight: 0,
      inputSizeKb: (_fileSizeBytes / 1024).round(),
      outputFormat: _outputFormat,
    );

    try {
      final options = ProcessOptions(
        sourcePath: widget.initialImage.path,
        targetSizeKB: targetKB,
        outputFormat: _outputFormat,
      );

      final result = await ImageProcessor.processImage(options);

      AnalyticsService.logCompressionUsed(
        targetQuality: result.finalQuality,
        originalSizeKb: (_fileSizeBytes / 1024).round(),
        compressedSizeKb: (result.outputSizeBytes / 1024).round(),
      );

      await CrashlyticsService.clearProcessingContext();

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(e, stack, reason: 'Image compression error');

      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error compressing image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.presetTitle ?? 'Compress Image'),
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
              // Image Preview Card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        child: Image.file(
                          widget.initialImage,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Size:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _fileSizeBytes.toReadableFileSize(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Target Size Input Header
              Text(
                'Target File Size (Strictly Under)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),

              // Target Size Text Field
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetSizeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: 'e.g. 50',
                        suffixText: 'KB',
                        suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null) {
                          setState(() => _selectedTargetSizeKB = parsed);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick Choice Chips
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
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedTargetSizeKB = sizeKB;
                          _targetSizeController.text = sizeKB.toString();
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Output Format Selector
              Text(
                'Output Format',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
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
                    onSelected: (selected) {
                      if (selected) setState(() => _outputFormat = fmt);
                    },
                  );
                }).toList(),
              ),
              if (_outputFormat == 'png') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PNG is a lossless format (best for logos & graphics). For camera photos and documents, PNG may result in larger file sizes.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => setState(() => _outputFormat = 'jpg'),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Switch to JPG (Recommended)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 36),

              // Action Button
              GradientButton(
                text: '⚡ Optimize to ${_targetSizeController.text.isEmpty ? "Target" : "${_targetSizeController.text} KB"}',
                isLoading: _isProcessing,
                onPressed: _isProcessing ? null : _handleCompress,
              ),
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
