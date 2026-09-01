import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/extensions/file_size_extension.dart';
import '../../data/models/process_options.dart';
import '../../services/image_service/image_processor.dart';
import '../result/result_screen.dart';
import '../widgets/gradient_button.dart';

class ConverterScreen extends StatefulWidget {
  final File initialImage;

  const ConverterScreen({
    super.key,
    required this.initialImage,
  });

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  String _sourceFormat = 'jpg';
  String _targetFormat = 'webp';
  double _quality = 85;
  bool _isProcessing = false;
  int _fileSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _fileSizeBytes = widget.initialImage.lengthSync();
    _sourceFormat = p.extension(widget.initialImage.path).replaceAll('.', '').toLowerCase();
    if (_sourceFormat.isEmpty) _sourceFormat = 'jpg';
    // Set default target to something different than source
    if (_sourceFormat == 'webp') {
      _targetFormat = 'jpg';
    } else {
      _targetFormat = 'webp';
    }
  }

  Future<void> _handleConvert() async {
    setState(() => _isProcessing = true);

    try {
      final options = ProcessOptions(
        sourcePath: widget.initialImage.path,
        outputFormat: _targetFormat,
        quality: _quality.round(),
      );

      final result = await ImageProcessor.processImage(options);

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
          content: Text('Error converting image: $e'),
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
        title: const Text('Convert Format'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview & Conversion Indicator
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _FormatBadge(format: _sourceFormat.toUpperCase(), isSource: true),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                              ),
                              _FormatBadge(format: _targetFormat.toUpperCase(), isSource: false),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Original Size: ${_fileSizeBytes.toReadableFileSize()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Target Format Selector
              Text(
                'Convert To',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: AppConstants.supportedOutputFormats.map((fmt) {
                  final isSelected = _targetFormat == fmt;
                  return ChoiceChip(
                    label: Text(fmt.toUpperCase()),
                    selected: isSelected,
                    selectedColor: AppColors.primaryContainerLight,
                    onSelected: (selected) {
                      if (selected) setState(() => _targetFormat = fmt);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Quality Slider (for JPG and WebP)
              if (_targetFormat != 'png') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Compression Quality',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      '${_quality.round()}%',
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
                  value: _quality,
                  min: 10,
                  max: 100,
                  divisions: 18,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _quality = val),
                ),
                Text(
                  'Recommended: 85% gives great clarity with ~70% smaller file size.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],

              const SizedBox(height: 36),

              GradientButton(
                text: '🔄 Convert to ${_targetFormat.toUpperCase()}',
                isLoading: _isProcessing,
                onPressed: _isProcessing ? null : _handleConvert,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String format;
  final bool isSource;

  const _FormatBadge({required this.format, required this.isSource});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSource ? AppColors.primaryContainerLight : AppColors.secondaryContainerLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        format,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isSource ? AppColors.primaryDark : AppColors.secondaryDark,
        ),
      ),
    );
  }
}
