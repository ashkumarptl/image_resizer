import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/extensions/file_size_extension.dart';
import '../../data/models/process_options.dart';
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

    try {
      final options = ProcessOptions(
        sourcePath: widget.initialImage.path,
        targetSizeKB: targetKB,
        outputFormat: _outputFormat,
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
          padding: const EdgeInsets.all(20),
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
                    selectedColor: AppColors.primaryContainerLight,
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
                    selectedColor: AppColors.primaryContainerLight,
                    onSelected: (selected) {
                      if (selected) setState(() => _outputFormat = fmt);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 36),

              // Action Button
              GradientButton(
                text: '⚡ Optimize to ${_targetSizeController.text.isEmpty ? "Target" : "${_targetSizeController.text} KB"}',
                isLoading: _isProcessing,
                onPressed: _isProcessing ? null : _handleCompress,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
