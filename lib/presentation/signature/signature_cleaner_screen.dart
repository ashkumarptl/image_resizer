import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/extensions/file_size_extension.dart';
import '../../services/image_service/signature_enhancer.dart';
import '../result/result_screen.dart';
import '../widgets/gradient_button.dart';

class SignatureCleanerScreen extends StatefulWidget {
  final File initialImage;

  const SignatureCleanerScreen({
    super.key,
    required this.initialImage,
  });

  @override
  State<SignatureCleanerScreen> createState() => _SignatureCleanerScreenState();
}

class _SignatureCleanerScreenState extends State<SignatureCleanerScreen> {
  double _threshold = 0.65;
  int _targetSizeKB = 19;
  bool _isProcessing = false;
  int _fileSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _fileSizeBytes = widget.initialImage.lengthSync();
  }

  Future<void> _handleEnhance() async {
    setState(() => _isProcessing = true);

    try {
      final options = SignatureEnhanceOptions(
        sourcePath: widget.initialImage.path,
        threshold: _threshold,
        targetSizeKB: _targetSizeKB,
        targetWidth: 400,
        targetHeight: 200,
      );

      final result = await SignatureEnhancer.enhanceSignature(options);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cleaning signature: $e'),
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
        title: const Text('Signature B&W Cleaner'),
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
              // Preview Box
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
                        height: 180,
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
                            'Raw Scanned Size:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _fileSizeBytes.toReadableFileSize(),
                            style: const TextStyle(
                              fontSize: 13,
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

              // Feature explanation banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primaryContainerDark : AppColors.primaryContainerLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_fix_high_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Removes paper shadows and turns ink into sharp high-contrast black on pure white background (Govt Exam ready).',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Background Removal Threshold Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Shadow Removal Strength',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    '${(_threshold * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: _threshold,
                min: 0.3,
                max: 0.9,
                divisions: 12,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _threshold = val),
              ),
              Text(
                'Adjust higher if your photo has darker paper shadows.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 24),

              // Target Size selection
              Text(
                'Target File Size',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [10, 19, 30, 50].map((size) {
                  final isSelected = _targetSizeKB == size;
                  return ChoiceChip(
                    label: Text(size == 19 ? '< 20 KB (SSC/Vyapam)' : '< $size KB'),
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
                      if (sel) setState(() => _targetSizeKB = size);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 36),

              GradientButton(
                text: '✍️ Clean & Compress Signature',
                isLoading: _isProcessing,
                onPressed: _isProcessing ? null : _handleEnhance,
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
