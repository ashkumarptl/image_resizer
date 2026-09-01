import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/extensions/file_size_extension.dart';
import '../../data/models/process_options.dart';
import '../../services/analytics_service.dart';
import '../../services/crashlytics_service.dart';
import '../../services/image_service/image_processor.dart';
import '../result/result_screen.dart';
import '../widgets/gradient_button.dart';

class ResizerScreen extends StatefulWidget {
  final File initialImage;

  const ResizerScreen({
    super.key,
    required this.initialImage,
  });

  @override
  State<ResizerScreen> createState() => _ResizerScreenState();
}

class _ResizerScreenState extends State<ResizerScreen> {
  int _originalWidth = 0;
  int _originalHeight = 0;
  int _fileSizeBytes = 0;
  bool _isLoadingInfo = true;

  bool _isPercentageMode = false;
  int _selectedPercentage = 50;

  late TextEditingController _widthController;
  late TextEditingController _heightController;
  bool _keepAspectRatio = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController();
    _heightController = TextEditingController();
    _fileSizeBytes = widget.initialImage.lengthSync();
    _loadImageMetadata();
  }

  Future<void> _loadImageMetadata() async {
    try {
      final bytes = await widget.initialImage.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        setState(() {
          _originalWidth = decoded.width;
          _originalHeight = decoded.height;
          _widthController.text = (_originalWidth * 0.5).round().toString();
          _heightController.text = (_originalHeight * 0.5).round().toString();
          _isLoadingInfo = false;
        });

        final ext = p.extension(widget.initialImage.path).replaceAll('.', '');
        AnalyticsService.logImageSelected(
          fileType: ext.isEmpty ? 'unknown' : ext,
          width: _originalWidth,
          height: _originalHeight,
          sizeKb: (_fileSizeBytes / 1024).round(),
        );
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(e, stack, reason: 'Failed to read image metadata in ResizerScreen');
      setState(() => _isLoadingInfo = false);
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _onWidthChanged(String value) {
    if (!_keepAspectRatio || _originalWidth == 0) return;
    final w = int.tryParse(value);
    if (w != null && w > 0) {
      final h = (_originalHeight * (w / _originalWidth)).round();
      _heightController.text = h.toString();
    }
  }

  void _onHeightChanged(String value) {
    if (!_keepAspectRatio || _originalHeight == 0) return;
    final h = int.tryParse(value);
    if (h != null && h > 0) {
      final w = (_originalWidth * (h / _originalHeight)).round();
      _widthController.text = w.toString();
    }
  }

  Future<void> _handleResize() async {
    setState(() => _isProcessing = true);

    final ext = p.extension(widget.initialImage.path).replaceAll('.', '');
    final fileType = ext.isEmpty ? 'jpg' : ext;

    await CrashlyticsService.setProcessingContext(
      operation: 'resize',
      inputWidth: _originalWidth,
      inputHeight: _originalHeight,
      inputSizeKb: (_fileSizeBytes / 1024).round(),
    );

    try {
      ProcessOptions options;

      if (_isPercentageMode) {
        options = ProcessOptions(
          sourcePath: widget.initialImage.path,
          resizeMode: ResizeMode.percentage,
          resizePercentage: _selectedPercentage,
        );

        AnalyticsService.logResizeStarted(
          outputFormat: fileType,
          targetWidth: (_originalWidth * (_selectedPercentage / 100)).round(),
          targetHeight: (_originalHeight * (_selectedPercentage / 100)).round(),
          resizeMode: 'percentage',
        );
      } else {
        final targetW = int.tryParse(_widthController.text.trim());
        final targetH = int.tryParse(_heightController.text.trim());

        options = ProcessOptions(
          sourcePath: widget.initialImage.path,
          resizeMode: ResizeMode.exactPixels,
          targetWidth: targetW,
          targetHeight: targetH,
          keepAspectRatio: _keepAspectRatio,
        );

        AnalyticsService.logResizeStarted(
          outputFormat: fileType,
          targetWidth: targetW ?? _originalWidth,
          targetHeight: targetH ?? _originalHeight,
          resizeMode: 'exact_pixels',
        );
      }

      final result = await ImageProcessor.processImage(options);

      AnalyticsService.logResizeCompleted(
        outputFormat: result.outputFormat,
        outputWidth: result.outputWidth,
        outputHeight: result.outputHeight,
        outputSizeKb: (result.outputSizeBytes / 1024).round(),
        durationMs: result.processingTime.inMilliseconds,
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
      AnalyticsService.logResizeFailed(
        reason: e.toString(),
        fileType: fileType,
        inputWidth: _originalWidth,
        inputHeight: _originalHeight,
      );
      CrashlyticsService.recordNonFatalError(e, stack, reason: 'Image resize execution error');

      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resizing image: $e'),
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
        title: const Text('Resize Image'),
      ),
      body: SafeArea(
        child: _isLoadingInfo
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preview & Dimensions Summary
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
                                Text(
                                  'Original: $_originalWidth × $_originalHeight px',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

                    // Resize Mode Toggle Segmented Button
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Exact Pixels'),
                          icon: Icon(Icons.aspect_ratio),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Percentage'),
                          icon: Icon(Icons.percent),
                        ),
                      ],
                      selected: {_isPercentageMode},
                      onSelectionChanged: (set) {
                        setState(() => _isPercentageMode = set.first);
                      },
                    ),
                    const SizedBox(height: 24),

                    if (!_isPercentageMode) ...[
                      // Exact Pixels Inputs
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Width (px)', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _widthController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onChanged: _onWidthChanged,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            child: IconButton(
                              icon: Icon(
                                _keepAspectRatio ? Icons.link : Icons.link_off,
                                color: _keepAspectRatio ? AppColors.primary : Colors.grey,
                              ),
                              tooltip: 'Lock Aspect Ratio',
                              onPressed: () {
                                setState(() => _keepAspectRatio = !_keepAspectRatio);
                              },
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Height (px)', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _heightController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onChanged: _onHeightChanged,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Percentage Chips
                      Text(
                        'Scale Down Percentage',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        children: AppConstants.defaultPercentagePresets.map((pct) {
                          final isSelected = _selectedPercentage == pct;
                          return ChoiceChip(
                            label: Text('$pct%'),
                            selected: isSelected,
                            selectedColor: AppColors.primaryContainerLight,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedPercentage = pct);
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 36),

                    GradientButton(
                      text: '⚡ Resize Now',
                      isLoading: _isProcessing,
                      onPressed: _isProcessing ? null : _handleResize,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
