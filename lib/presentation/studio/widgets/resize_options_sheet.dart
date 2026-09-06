import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/file_size_extension.dart';

enum ResizeSheetOption { none, exactPixels, percentage }

class ResizePreset {
  final String id;
  final String name;
  final String category; // 'popular', 'social', 'documents'
  final int? width; // null for original
  final int? height; // null for original
  final IconData? icon;
  final Color? iconColor;
  final bool isBrandInstagram;
  final bool isBrandYouTube;
  final bool isBrandLinkedIn;
  final bool isBrandTikTok;

  const ResizePreset({
    required this.id,
    required this.name,
    required this.category,
    this.width,
    this.height,
    this.icon,
    this.iconColor,
    this.isBrandInstagram = false,
    this.isBrandYouTube = false,
    this.isBrandLinkedIn = false,
    this.isBrandTikTok = false,
  });

  bool get isOriginal => width == null || height == null;
}

class ResizeOptionsSheet extends StatefulWidget {
  final ResizeSheetOption initialOption;
  final int originalWidth;
  final int originalHeight;
  final int originalSizeBytes;
  final int initialTargetWidth;
  final int initialTargetHeight;
  final int initialPercentage;
  final bool initialKeepAspectRatio;
  final Function({
    required ResizeSheetOption option,
    required int targetWidth,
    required int targetHeight,
    required int percentage,
    required bool keepAspectRatio,
  }) onApply;

  const ResizeOptionsSheet({
    super.key,
    required this.initialOption,
    required this.originalWidth,
    required this.originalHeight,
    this.originalSizeBytes = 0,
    required this.initialTargetWidth,
    required this.initialTargetHeight,
    required this.initialPercentage,
    required this.initialKeepAspectRatio,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required ResizeSheetOption initialOption,
    required int originalWidth,
    required int originalHeight,
    int originalSizeBytes = 0,
    required int initialTargetWidth,
    required int initialTargetHeight,
    required int initialPercentage,
    required bool initialKeepAspectRatio,
    required Function({
      required ResizeSheetOption option,
      required int targetWidth,
      required int targetHeight,
      required int percentage,
      required bool keepAspectRatio,
    }) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ResizeOptionsSheet(
        initialOption: initialOption,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        originalSizeBytes: originalSizeBytes,
        initialTargetWidth: initialTargetWidth,
        initialTargetHeight: initialTargetHeight,
        initialPercentage: initialPercentage,
        initialKeepAspectRatio: initialKeepAspectRatio,
        onApply: onApply,
      ),
    );
  }

  @override
  State<ResizeOptionsSheet> createState() => _ResizeOptionsSheetState();
}

class _ResizeOptionsSheetState extends State<ResizeOptionsSheet> {
  // Active top tab: 0 = Presets, 1 = Custom, 2 = Percentage
  late int _activeTab;

  // Selected preset tracking
  String? _selectedPresetId;

  // Custom tab controllers & state
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late bool _keepAspectRatio;
  int _selectedUnitIndex = 0; // 0 = px, 1 = in, 2 = cm

  // Percentage tab state
  late int _percentage;

  // Expand toggles for "See All >"
  bool _expandSocial = false;
  bool _expandDocuments = false;

  // Presets Data Definition
  static const List<ResizePreset> _popularPresets = [
    ResizePreset(
      id: 'original',
      name: 'Original',
      category: 'popular',
      icon: Icons.image_outlined,
    ),
    ResizePreset(
      id: 'square',
      name: 'Square',
      category: 'popular',
      width: 1080,
      height: 1080,
      icon: Icons.crop_square_rounded,
    ),
    ResizePreset(
      id: 'portrait',
      name: 'Portrait',
      category: 'popular',
      width: 1080,
      height: 1350,
      icon: Icons.crop_portrait_rounded,
    ),
    ResizePreset(
      id: 'story',
      name: 'Story',
      category: 'popular',
      width: 1080,
      height: 1920,
      icon: Icons.smartphone_rounded,
    ),
    ResizePreset(
      id: 'hd',
      name: 'HD',
      category: 'popular',
      width: 1280,
      height: 720,
      icon: Icons.tv_rounded,
    ),
    ResizePreset(
      id: 'full_hd',
      name: 'Full HD',
      category: 'popular',
      width: 1920,
      height: 1080,
      icon: Icons.desktop_windows_rounded,
    ),
    ResizePreset(
      id: '2k',
      name: '2K',
      category: 'popular',
      width: 2560,
      height: 1440,
      icon: Icons.monitor_rounded,
    ),
    ResizePreset(
      id: '4k',
      name: '4K',
      category: 'popular',
      width: 3840,
      height: 2160,
      icon: Icons.four_k_rounded,
    ),
  ];

  static const List<ResizePreset> _socialPresets = [
    ResizePreset(
      id: 'ig_square',
      name: 'Insta Post',
      category: 'social',
      width: 1080,
      height: 1080,
      isBrandInstagram: true,
    ),
    ResizePreset(
      id: 'ig_story',
      name: 'Insta Story',
      category: 'social',
      width: 1080,
      height: 1920,
      isBrandInstagram: true,
    ),
    ResizePreset(
      id: 'yt_thumb',
      name: 'YouTube Thumb',
      category: 'social',
      width: 1280,
      height: 720,
      isBrandYouTube: true,
    ),
    ResizePreset(
      id: 'li_post',
      name: 'LinkedIn Post',
      category: 'social',
      width: 1200,
      height: 627,
      isBrandLinkedIn: true,
    ),
    ResizePreset(
      id: 'ig_portrait',
      name: 'Insta Portrait',
      category: 'social',
      width: 1080,
      height: 1350,
      isBrandInstagram: true,
    ),
    ResizePreset(
      id: 'yt_fhd',
      name: 'YouTube FHD',
      category: 'social',
      width: 1920,
      height: 1080,
      isBrandYouTube: true,
    ),
    ResizePreset(
      id: 'li_square',
      name: 'LinkedIn Square',
      category: 'social',
      width: 1200,
      height: 1200,
      isBrandLinkedIn: true,
    ),
    ResizePreset(
      id: 'li_portrait',
      name: 'LinkedIn Portrait',
      category: 'social',
      width: 720,
      height: 900,
      isBrandLinkedIn: true,
    ),
    ResizePreset(
      id: 'tiktok_vertical',
      name: 'TikTok Vertical',
      category: 'social',
      width: 1080,
      height: 1920,
      isBrandTikTok: true,
    ),
  ];

  static const List<ResizePreset> _documentPresets = [
    ResizePreset(
      id: 'a4_portrait',
      name: 'A4 Portrait',
      category: 'documents',
      width: 2480,
      height: 3508,
      icon: Icons.description_outlined,
    ),
    ResizePreset(
      id: 'a4_landscape',
      name: 'A4 Landscape',
      category: 'documents',
      width: 3508,
      height: 2480,
      icon: Icons.crop_landscape_rounded,
    ),
    ResizePreset(
      id: 'passport',
      name: 'Passport',
      category: 'documents',
      width: 413,
      height: 531,
      icon: Icons.badge_outlined,
    ),
    ResizePreset(
      id: 'signature',
      name: 'Signature',
      category: 'documents',
      width: 400,
      height: 200,
      icon: Icons.draw_outlined,
    ),
    ResizePreset(
      id: 'doc_hd',
      name: 'Document HD',
      category: 'documents',
      width: 1920,
      height: 1080,
      icon: Icons.document_scanner_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _percentage = widget.initialPercentage > 0 ? widget.initialPercentage : 50;
    _keepAspectRatio = widget.initialKeepAspectRatio;

    final initialW = widget.initialTargetWidth > 0
        ? widget.initialTargetWidth
        : widget.originalWidth;
    final initialH = widget.initialTargetHeight > 0
        ? widget.initialTargetHeight
        : widget.originalHeight;

    _widthController = TextEditingController(text: initialW.toString());
    _heightController = TextEditingController(text: initialH.toString());

    // Determine initial tab and preset selection
    if (widget.initialOption == ResizeSheetOption.percentage) {
      _activeTab = 2; // Percentage
      _selectedPresetId = null;
    } else if (widget.initialOption == ResizeSheetOption.exactPixels) {
      // Check if it matches an existing preset
      final match = _findMatchingPreset(initialW, initialH);
      if (match != null) {
        _activeTab = 0; // Presets
        _selectedPresetId = match.id;
      } else {
        _activeTab = 1; // Custom
        _selectedPresetId = null;
      }
    } else {
      // None -> Original
      _activeTab = 0; // Presets
      _selectedPresetId = 'original';
    }
  }

  ResizePreset? _findMatchingPreset(int w, int h) {
    for (final p in [
      ..._popularPresets,
      ..._socialPresets,
      ..._documentPresets,
    ]) {
      if (!p.isOriginal && p.width == w && p.height == h) {
        return p;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _onWidthChanged(String val) {
    if (!_keepAspectRatio) return;
    final w = int.tryParse(val);
    if (w != null && widget.originalWidth > 0) {
      final h = (widget.originalHeight * (w / widget.originalWidth)).round();
      _heightController.text = h.toString();
    }
  }

  void _onHeightChanged(String val) {
    if (!_keepAspectRatio) return;
    final h = int.tryParse(val);
    if (h != null && widget.originalHeight > 0) {
      final w = (widget.originalWidth * (h / widget.originalHeight)).round();
      _widthController.text = w.toString();
    }
  }

  void _selectPreset(ResizePreset preset) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPresetId = preset.id;
      if (preset.isOriginal) {
        _widthController.text = widget.originalWidth.toString();
        _heightController.text = widget.originalHeight.toString();
      } else {
        _widthController.text = preset.width.toString();
        _heightController.text = preset.height.toString();
      }
    });
  }

  void _handleApply() {
    HapticFeedback.lightImpact();

    ResizeSheetOption finalOption;
    int finalW;
    int finalH;

    if (_activeTab == 0) {
      // Presets Tab
      if (_selectedPresetId == 'original') {
        finalOption = ResizeSheetOption.none;
        finalW = widget.originalWidth;
        finalH = widget.originalHeight;
      } else {
        finalOption = ResizeSheetOption.exactPixels;
        finalW = int.tryParse(_widthController.text) ?? widget.originalWidth;
        finalH = int.tryParse(_heightController.text) ?? widget.originalHeight;
      }
    } else if (_activeTab == 1) {
      // Custom Tab
      finalW = int.tryParse(_widthController.text) ?? widget.originalWidth;
      finalH = int.tryParse(_heightController.text) ?? widget.originalHeight;
      final isOriginal = (finalW == widget.originalWidth && finalH == widget.originalHeight);
      finalOption = isOriginal ? ResizeSheetOption.none : ResizeSheetOption.exactPixels;
    } else {
      // Percentage Tab
      final isOriginal = (_percentage == 100);
      finalOption = isOriginal ? ResizeSheetOption.none : ResizeSheetOption.percentage;
      finalW = (widget.originalWidth * _percentage / 100).round();
      finalH = (widget.originalHeight * _percentage / 100).round();
    }

    widget.onApply(
      option: finalOption,
      targetWidth: finalW,
      targetHeight: finalH,
      percentage: _percentage,
      keepAspectRatio: _keepAspectRatio,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
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
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row: Icon, Title, Subtitle & Close Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.open_in_full_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Resize Dimensions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose a preset size or enter custom dimensions',
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
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 22),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3-Way Segmented Navigation Bar: Presets | Custom | Percentage
          _buildSegmentedTabBar(isDark),
          const SizedBox(height: 14),

          // Active Tab Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_activeTab == 0) _buildPresetsTab(isDark),
                  if (_activeTab == 1) _buildCustomTab(isDark),
                  if (_activeTab == 2) _buildPercentageTab(isDark),
                  const SizedBox(height: 14),
                  _buildTipBox(isDark),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom Action Button: Apply Resize Dimensions
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handleApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: const StadiumBorder(),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Apply Resize Dimensions',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Top 3-Way Segmented Tabs
  // --------------------------------------------------------------------------
  Widget _buildSegmentedTabBar(bool isDark) {
    final tabs = [
      (0, Icons.grid_view_rounded, 'Presets'),
      (1, Icons.edit_outlined, 'Custom'),
      (2, Icons.percent_rounded, 'Percentage'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: tabs.map((tab) {
          final index = tab.$1;
          final icon = tab.$2;
          final label = tab.$3;
          final isSelected = _activeTab == index;

          return Expanded(
            child: Material(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              elevation: isSelected ? 1 : 0,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeTab = index);
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Tab 1: Presets
  // --------------------------------------------------------------------------
  Widget _buildPresetsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Popular Presets Section
        _buildSectionHeader('Popular', null, null, isDark),
        const SizedBox(height: 8),
        _buildPresetGrid(_popularPresets, isDark),
        const SizedBox(height: 18),

        // 2. Social Media Section
        _buildSectionHeader(
          'Social Media',
          _expandSocial ? 'Show Less' : 'See All >',
          () => setState(() => _expandSocial = !_expandSocial),
          isDark,
        ),
        const SizedBox(height: 8),
        _buildPresetGrid(
          _expandSocial ? _socialPresets : _socialPresets.take(4).toList(),
          isDark,
        ),
        const SizedBox(height: 18),

        // 3. Documents Section
        _buildSectionHeader(
          'Documents',
          _expandDocuments ? 'Show Less' : 'See All >',
          () => setState(() => _expandDocuments = !_expandDocuments),
          isDark,
        ),
        const SizedBox(height: 8),
        _buildPresetGrid(
          _expandDocuments ? _documentPresets : _documentPresets.take(4).toList(),
          isDark,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    String? actionLabel,
    VoidCallback? onAction,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        if (actionLabel != null && onAction != null)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onAction();
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPresetGrid(List<ResizePreset> presets, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 4;
        const spacing = 8.0;
        final itemWidth = (constraints.maxWidth - ((crossAxisCount - 1) * spacing)) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: presets.map((preset) {
            final isSelected = _selectedPresetId == preset.id;

            return SizedBox(
              width: itemWidth,
              child: Material(
                color: isSelected
                    ? (isDark ? AppColors.primary.withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _selectPreset(preset),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.6 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPresetIcon(preset, isSelected, isDark),
                        const SizedBox(height: 6),
                        Text(
                          preset.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.isOriginal
                              ? '${widget.originalWidth} × ${widget.originalHeight}'
                              : '${preset.width} × ${preset.height}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.85)
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPresetIcon(ResizePreset preset, bool isSelected, bool isDark) {
    if (preset.isBrandInstagram) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
      );
    }

    if (preset.isBrandYouTube) {
      return Container(
        width: 26,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFFFF0000),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
      );
    }

    if (preset.isBrandLinkedIn) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFF0A66C2),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Center(
          child: Text(
            'in',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              fontFamily: 'sans-serif',
            ),
          ),
        ),
      );
    }

    if (preset.isBrandTikTok) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isDark ? Colors.black : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.music_note_rounded, color: Color(0xFF00F2FE), size: 16),
      );
    }

    return Icon(
      preset.icon ?? Icons.aspect_ratio_rounded,
      size: 24,
      color: isSelected
          ? AppColors.primary
          : (preset.iconColor ??
              (isDark ? AppColors.textSecondaryDark : const Color(0xFF475569))),
    );
  }

  // --------------------------------------------------------------------------
  // Tab 2: Custom Dimensions
  // --------------------------------------------------------------------------
  Widget _buildCustomTab(bool isDark) {
    const commonSizes = [256, 512, 768, 1024, 1280];
    final currentW = int.tryParse(_widthController.text);
    final sizeSuffix = widget.originalSizeBytes > 0
        ? ' (${widget.originalSizeBytes.toReadableFileSize()})'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enter Dimensions Header with Reset Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Enter Dimensions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _widthController.text = widget.originalWidth.toString();
                  _heightController.text = widget.originalHeight.toString();
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 15, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Width & Height TextFields with Link button in middle
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _widthController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Width',
                  suffixText: _selectedUnitIndex == 0 ? 'px' : (_selectedUnitIndex == 1 ? 'in' : 'cm'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: _onWidthChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Material(
                color: _keepAspectRatio
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : (isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _keepAspectRatio = !_keepAspectRatio);
                    if (_keepAspectRatio) {
                      _onWidthChanged(_widthController.text);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _keepAspectRatio ? AppColors.primary : Colors.grey.shade300,
                      ),
                    ),
                    child: Icon(
                      _keepAspectRatio ? Icons.link_rounded : Icons.link_off_rounded,
                      color: _keepAspectRatio ? AppColors.primary : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Height',
                  suffixText: _selectedUnitIndex == 0 ? 'px' : (_selectedUnitIndex == 1 ? 'in' : 'cm'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: _onHeightChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Common Sizes Quick Pills
        Text(
          'Common Sizes',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: commonSizes.map((size) {
              final isMatch = currentW == size;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: isMatch
                      ? (isDark ? AppColors.primary.withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
                      : (isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _widthController.text = size.toString();
                      _onWidthChanged(size.toString());
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isMatch
                              ? AppColors.primary
                              : (isDark ? AppColors.borderDark : const Color(0xFFCBD5E1)),
                          width: isMatch ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        size.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isMatch ? FontWeight.bold : FontWeight.w600,
                          color: isMatch
                              ? AppColors.primary
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        // More Options: Unit Selector
        Text(
          'More Options',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Unit',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _buildUnitButton('Pixels (px)', 0, isDark),
              _buildUnitButton('Inches (in)', 1, isDark),
              _buildUnitButton('Centimeters (cm)', 2, isDark),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Keep Aspect Ratio Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keep Aspect Ratio',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'When enabled, height adjusts automatically.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: _keepAspectRatio,
              activeTrackColor: AppColors.primary,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() => _keepAspectRatio = val);
                if (val) _onWidthChanged(_widthController.text);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Original Size Card with "Use Original" button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.image_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original Size',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.originalWidth} × ${widget.originalHeight} px$sizeSuffix',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _widthController.text = widget.originalWidth.toString();
                    _heightController.text = widget.originalHeight.toString();
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Use Original',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitButton(String label, int index, bool isDark) {
    final isSelected = _selectedUnitIndex == index;

    return Expanded(
      child: Material(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedUnitIndex = index);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Tab 3: Percentage Scale
  // --------------------------------------------------------------------------
  Widget _buildPercentageTab(bool isDark) {
    const presetPills = [25, 50, 75, 100, 150];
    final resultingW = (widget.originalWidth * _percentage / 100).round();
    final resultingH = (widget.originalHeight * _percentage / 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Scale Percentage',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Resize your image by a percentage of its original size.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 12),

        // Quick Percentage Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: presetPills.map((p) {
              final isSelected = _percentage == p;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _percentage = p);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.borderDark : const Color(0xFFCBD5E1)),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        '$p%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Value Indicator Bubble & Slider
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$_percentage%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        Slider(
          value: _percentage.toDouble().clamp(10, 200),
          min: 10,
          max: 200,
          divisions: 38,
          activeColor: AppColors.primary,
          onChanged: (val) {
            final rounded = val.round();
            if (rounded != _percentage) {
              setState(() => _percentage = rounded);
            }
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '10%',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            Text(
              '200%',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Resulting Size Card with Percentage Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.image_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resulting Size',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$resultingW × $resultingH px',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Original: ${widget.originalWidth} × ${widget.originalHeight} px',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _percentage < 100
                      ? const Color(0xFFDCFCE7)
                      : (_percentage > 100 ? const Color(0xFFE0F2FE) : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _percentage < 100
                      ? '-${100 - _percentage}%'
                      : (_percentage > 100 ? '+${_percentage - 100}%' : '100%'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _percentage < 100
                        ? const Color(0xFF166534)
                        : (_percentage > 100 ? AppColors.primary : Colors.grey.shade800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Keep Aspect Ratio Switch
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keep Aspect Ratio',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'When enabled, both width and height will be scaled proportionally.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: _keepAspectRatio,
              activeTrackColor: AppColors.primary,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() => _keepAspectRatio = val);
              },
            ),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Bottom Helpful Tip Box
  // --------------------------------------------------------------------------
  Widget _buildTipBox(bool isDark) {
    String tipMessage;
    if (_activeTab == 0) {
      tipMessage =
          'Presets are optimized sizes for common use cases. You can also enter custom size or percentage.';
    } else if (_activeTab == 1) {
      tipMessage =
          'Enter your desired width or height. With aspect ratio locked, the other value will be calculated automatically.';
    } else {
      tipMessage =
          'Use percentage to quickly reduce or increase the image size. Useful when you want to keep the same aspect ratio.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? AppColors.textPrimaryDark : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tipMessage,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
