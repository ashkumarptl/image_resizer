import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/repositories/tool_guide_repository.dart';
import '../../services/image_service/perspective_cropper.dart';
import '../perspective_crop/perspective_crop_screen.dart';
import '../result/result_screen.dart';
import '../widgets/tool_instruction_sheet.dart';

class _FilterItem {
  final PerspectiveFilter filter;
  final String title;
  final String? badge;

  const _FilterItem({
    required this.filter,
    required this.title,
    this.badge,
  });
}

class DocumentFilterScreen extends StatefulWidget {
  final File initialImage;
  final bool returnFilteredFile;

  const DocumentFilterScreen({
    super.key,
    required this.initialImage,
    this.returnFilteredFile = false,
  });

  @override
  State<DocumentFilterScreen> createState() => _DocumentFilterScreenState();
}

class _DocumentFilterScreenState extends State<DocumentFilterScreen> {
  late File _currentImage;
  int _quarterTurns = 0;
  PerspectiveFilter _selectedFilter = PerspectiveFilter.vividLight;
  bool _isComparing = false;
  bool _isProcessing = false;

  static const List<_FilterItem> _filters = [
    _FilterItem(
      filter: PerspectiveFilter.none,
      title: 'Original',
    ),
    _FilterItem(
      filter: PerspectiveFilter.vividLight,
      title: 'Vivid Light',
      badge: 'Pro',
    ),
    _FilterItem(
      filter: PerspectiveFilter.contrastBw,
      title: 'Contrast B&W',
      badge: 'Pro',
    ),
    _FilterItem(
      filter: PerspectiveFilter.enhanced,
      title: 'Vibrant',
    ),
    _FilterItem(
      filter: PerspectiveFilter.documentBw,
      title: 'Doc B&W',
      badge: 'AI',
    ),
    _FilterItem(
      filter: PerspectiveFilter.grayscale,
      title: 'Grayscale',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentImage = widget.initialImage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ToolInstructionSheet.show(context, ToolGuideType.documentFilter);
    });
  }

  void _handleRotate() {
    HapticFeedback.lightImpact();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  void _openPerspectiveCrop() async {
    HapticFeedback.mediumImpact();
    final croppedFile = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => PerspectiveCropScreen(
          initialImage: _currentImage,
          returnCroppedFile: true,
        ),
      ),
    );

    if (croppedFile != null && mounted) {
      setState(() {
        _currentImage = croppedFile;
        _quarterTurns = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document straightened! Now select your preferred filter.'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleApply() async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final result = await PerspectiveCropper.processFilter(
        _currentImage,
        _selectedFilter,
        quarterTurns: _quarterTurns,
        quality: 92,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (widget.returnFilteredFile) {
        Navigator.of(context).pop(File(result.outputPath));
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(result: result),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply filter: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  ColorFilter? _getEffectiveColorFilter(PerspectiveFilter filter) {
    if (_isComparing) return null;
    return DocumentFilterHelper.getColorFilter(filter);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = context.isMediumOrWider;

    final bgColor = isDark ? AppColors.backgroundDark : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: isWide
            ? Row(
                children: [
                  Expanded(child: _buildPreviewArea(isDark)),
                  Container(
                    width: 360,
                    margin: const EdgeInsets.only(right: 16, top: 12, bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(18),
                            child: _buildWideControls(isDark),
                          ),
                        ),
                        _buildBottomBar(isDark),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(child: _buildPreviewArea(isDark)),
                  _buildControlsPanel(isDark),
                  _buildBottomBar(isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildPreviewArea(bool isDark) {
    final activeFilter = _isComparing ? PerspectiveFilter.none : _selectedFilter;
    final colorFilter = _getEffectiveColorFilter(activeFilter);

    Widget imageWidget = Image.file(
      _currentImage,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    if (colorFilter != null) {
      imageWidget = ColorFiltered(
        colorFilter: colorFilter,
        child: imageWidget,
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Hero Zoomable Document Canvas
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.22),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: RotatedBox(
                      quarterTurns: _quarterTurns,
                      child: imageWidget,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Floating Top Shortcuts (Help & Straighten & Rotate)
        Positioned(
          top: 10,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFloatingIconBtn(
                icon: Icons.help_outline_rounded,
                tooltip: 'How to use Document Filter',
                onPressed: () {
                  ToolInstructionSheet.show(
                    context,
                    ToolGuideType.documentFilter,
                    isManualTrigger: true,
                  );
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFloatingIconBtn(
                icon: Icons.crop_rotate_rounded,
                tooltip: 'Tilted? Straighten Corners',
                onPressed: _openPerspectiveCrop,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFloatingIconBtn(
                icon: Icons.rotate_right_rounded,
                tooltip: 'Rotate 90°',
                onPressed: _handleRotate,
                isDark: isDark,
              ),
            ],
          ),
        ),

        // 3. Active Comparing Indicator Banner
        if (_isComparing)
          Positioned(
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.amber, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_rounded, size: 15, color: Colors.amber),
                  SizedBox(width: 6),
                  Text(
                    'Showing Original (Unfiltered)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 4. Floating Glassmorphic "Hold to Compare" Button
        Positioned(
          bottom: 12,
          right: 14,
          child: Listener(
            onPointerDown: (_) {
              HapticFeedback.selectionClick();
              setState(() => _isComparing = true);
            },
            onPointerUp: (_) {
              if (mounted) setState(() => _isComparing = false);
            },
            onPointerCancel: (_) {
              if (mounted) setState(() => _isComparing = false);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _isComparing
                        ? Colors.black.withValues(alpha: 0.88)
                        : Colors.black.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isComparing ? Colors.amber : Colors.white24,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.compare_rounded,
                        size: 15,
                        color: _isComparing ? Colors.amber : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Hold to Compare',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingIconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: isDark
              ? AppColors.surfaceDark.withValues(alpha: 0.75)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onPressed,
            child: Tooltip(
              message: tooltip,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Controls Panel (Tools row + Filter Cards strip)
  Widget _buildControlsPanel(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Presets',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                Text(
                  _filters.firstWhere((f) => f.filter == _selectedFilter).title,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _buildFilterThumbnailCard(_filters[index], isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Filter Card Thumbnail
  Widget _buildFilterThumbnailCard(_FilterItem item, bool isDark) {
    final isSelected = _selectedFilter == item.filter;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = item.filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 86,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Live Filter Preview Thumbnail
              _buildThumbnailPreview(item.filter),

              // 2. Pro / AI Badge (Top Right)
              if (item.badge != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC026D3), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.35),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      item.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

              // 3. Bottom Label Banner
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : Colors.black.withValues(alpha: 0.58),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPreview(PerspectiveFilter filter) {
    final colorFilter = DocumentFilterHelper.getColorFilter(filter);

    Widget thumb = Image.file(
      _currentImage,
      fit: BoxFit.cover,
      cacheWidth: 140,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => const Icon(
        Icons.document_scanner_rounded,
        size: 20,
        color: Colors.white38,
      ),
    );

    if (colorFilter != null) {
      thumb = ColorFiltered(
        colorFilter: colorFilter,
        child: thumb,
      );
    }

    return RotatedBox(
      quarterTurns: _quarterTurns,
      child: thumb,
    );
  }

  /// Bottom Bar with ✕, "Color Filter", and ✓
  Widget _buildBottomBar(bool isDark) {
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close / Cancel Button
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 26,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            tooltip: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),

          // Title: Color Filter
          Text(
            'Color Filter',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              letterSpacing: 0.2,
            ),
          ),

          // Apply / Checkmark Button
          _isProcessing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : IconButton(
                  icon: Icon(
                    Icons.check_rounded,
                    size: 30,
                    color: primaryColor,
                  ),
                  tooltip: 'Apply & Save Scan',
                  onPressed: _handleApply,
                ),
        ],
      ),
    );
  }

  /// Controls Panel for Wide Tablet layout
  Widget _buildWideControls(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Adjust & Presets',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openPerspectiveCrop,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.crop_rotate_rounded,
                      size: 15,
                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Deskew Doc',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Text(
          'Filter Presets',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 10),

        // Grid of filter cards for tablet
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _filters.map((item) {
            return SizedBox(
              width: 96,
              height: 116,
              child: _buildFilterThumbnailCard(item, isDark),
            );
          }).toList(),
        ),
      ],
    );
  }
}
