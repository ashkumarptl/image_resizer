import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/scan_project.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/tool_guide_repository.dart';
import '../../services/scanner/document_scanner_service.dart';
import '../../services/scanner/scan_project_service.dart';
import '../../services/storage_service.dart';
import '../widgets/account_section.dart';
import '../widgets/login_gate_dialog.dart';
import '../widgets/send_to_pc_sheet.dart';
import '../widgets/tool_instruction_sheet.dart';
import 'scan_project_detail_screen.dart';

class ScanToPdfScreen extends ConsumerStatefulWidget {
  final bool isTab;
  final List<ScanProject>? initialProjects;

  const ScanToPdfScreen({super.key, this.isTab = false, this.initialProjects});

  @override
  ConsumerState<ScanToPdfScreen> createState() => _ScanToPdfScreenState();
}

class _ScanToPdfScreenState extends ConsumerState<ScanToPdfScreen> {
  final DocumentScannerService _scannerService = DocumentScannerService();
  final ScanProjectService _projectService = ScanProjectService.instance;
  final Set<String> _savedPdfPaths = {};
  final TextEditingController _searchController = TextEditingController();
  List<ScanProject> _projects = [];
  String _searchQuery = '';
  String _sortBy = 'date_desc';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProjects != null) {
      _projects = List.of(widget.initialProjects!);
    } else {
      _loadProjects();
    }
    if (!widget.isTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ToolInstructionSheet.show(context, ToolGuideType.scanToPdf);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ScanProject> get _filteredProjects {
    var list = List<ScanProject>.from(_projects);
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(query)).toList();
    }
    switch (_sortBy) {
      case 'name_asc':
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'size_desc':
        list.sort((a, b) => b.pdfSizeBytes.compareTo(a.pdfSizeBytes));
        break;
      case 'date_asc':
        list.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case 'date_desc':
      default:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }
    return list;
  }

  Future<void> _loadProjects() async {
    final list = await _projectService.loadProjects();
    if (mounted) {
      setState(() {
        _projects = list;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _handleScanWithCamera() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _scannerService.scanToPdf(
        pageLimit: 50,
        isGalleryImport: true,
      );

      if (result != null && mounted) {
        HapticFeedback.mediumImpact();
        final now = DateTime.now();
        final defaultName = 'Scan ${DateFormat('d MMM, h:mm a').format(now)}';
        final project = await _projectService.createProject(
          name: defaultName,
          imageFiles: result.pageImages,
          existingPdf: result.pdfFile,
        );

        await _loadProjects();

        if (mounted) {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) =>
                      ScanProjectDetailScreen(initialProject: project),
                ),
              )
              .then((_) => _loadProjects());
        }
      }
    } catch (e) {
      debugPrint('[ScanToPdfScreen] Scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete scan: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleImportFromGallery() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    try {
      final picker = ImagePicker();
      final pickedImages = await picker.pickMultiImage();

      if (pickedImages.isEmpty || !mounted) return;

      setState(() => _isProcessing = true);

      final imageFiles = pickedImages.map((x) => File(x.path)).toList();
      final now = DateTime.now();
      final defaultName = 'Doc ${DateFormat('d MMM, h:mm a').format(now)}';

      final project = await _projectService.createProject(
        name: defaultName,
        imageFiles: imageFiles,
      );

      await _loadProjects();

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) =>
                    ScanProjectDetailScreen(initialProject: project),
              ),
            )
            .then((_) => _loadProjects());
      }
    } catch (e) {
      debugPrint('[ScanToPdfScreen] Gallery to PDF error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating project from gallery: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleSaveProjectPdf(ScanProject project) async {
    if (project.pdfPath == null) return;

    try {
      final savedFile = await StorageService.savePdfToDevice(
        project.pdfPath!,
        customFileName: '${project.name.replaceAll(' ', '_')}.pdf',
      );

      if (savedFile != null && mounted) {
        HapticFeedback.lightImpact();
        setState(() => _savedPdfPaths.add(project.id));
        final fileName = savedFile.path.split('/').last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to Downloads! ($fileName)'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => _handleShareProjectPdf(project),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ScanToPdfScreen] Save error: $e');
    }
  }

  Future<void> _handleShareProjectPdf(ScanProject project) async {
    if (project.pdfPath == null) return;
    final file = File(project.pdfPath!);
    if (!file.existsSync()) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Material(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${project.pageCount} pages • ${_formatBytes(project.pdfSizeBytes)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.share_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text(
                      'Share to Apps',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Share PDF via WhatsApp, Gmail, Drive, etc.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(ctx).pop('apps'),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.laptop_chromebook_rounded,
                        color: AppColors.secondary,
                      ),
                    ),
                    title: Row(
                      children: [
                        const Text(
                          'Send to PC / Browser',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Cyber Cafe',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Direct wireless transfer to any PC browser via QR Code / URL',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(ctx).pop('pc'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (action == 'apps' && mounted) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(project.pdfPath!)],
            text: '${project.name} (${project.pageCount} pages)',
          ),
        );
      } catch (e) {
        debugPrint('[ScanToPdfScreen] Share error: $e');
      }
    } else if (action == 'pc' && mounted) {
      SendToPcSheet.show(context, filePaths: [project.pdfPath!]);
    }
  }

  Future<void> _handleDeleteProject(ScanProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${project.name}"?'),
        content: const Text(
          'This will permanently remove this project and all its pages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _projectService.deleteProject(project.id);
      _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = context.isMediumOrWider;

    final safeBottom = math.max(
      MediaQuery.paddingOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    final double bottomMargin;
    if (safeBottom >= 36) {
      bottomMargin = safeBottom + 12.0;
    } else if (safeBottom > 0) {
      bottomMargin = safeBottom + 8.0;
    } else {
      bottomMargin = 16.0;
    }
    final double fabBottomPadding = (widget.isTab && !isWide)
        ? (bottomMargin - 8.0)
        : 24.0;

    return Scaffold(
      key: const ValueKey("scan_to_pdf_scaffold"),
      appBar: AppBar(
        toolbarHeight: context.isLargeTablet
            ? 84
            : (context.isMediumOrWider ? 72 : null),
        automaticallyImplyLeading: !widget.isTab,
        title: Text(
          'Scan to PDF',
          style: TextStyle(
            fontSize: context.adaptiveFontSize(
              20,
              tabletSize: 24,
              largeTabletSize: 28,
            ),
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.help_outline_rounded,
              size: context.adaptiveIconSize(
                22,
                tabletSize: 26,
                largeTabletSize: 30,
              ),
            ),
            tooltip: 'How to use Scan to PDF',
            onPressed: () {
              ToolInstructionSheet.show(
                context,
                ToolGuideType.scanToPdf,
                isManualTrigger: true,
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.info_outline_rounded,
              size: context.adaptiveIconSize(
                21,
                tabletSize: 25,
                largeTabletSize: 29,
              ),
            ),
            tooltip: 'Scanning Tips',
            onPressed: () => _showTipsBottomSheet(context),
          ),
          Consumer(
            builder: (context, ref, child) {
              final authState = ref.watch(authStateProvider);
              return authState.when(
                data: (user) {
                  if (user != null) {
                    final photoUrl = user.photoURL;
                    final displayName = user.displayName ?? 'User';
                    return IconButton(
                      tooltip: 'Account (${user.displayName ?? 'Signed in'})',
                      onPressed: () => showAccountBottomSheet(context),
                      icon: CircleAvatar(
                        radius: context.isLargeTablet
                            ? 24
                            : (context.isMediumOrWider ? 20 : 14),
                        backgroundColor: AppColors.primaryContainerLight,
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: context.adaptiveFontSize(
                                    12,
                                    tabletSize: 16,
                                    largeTabletSize: 19,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              )
                            : null,
                      ),
                    );
                  } else {
                    return IconButton(
                      icon: Icon(
                        Icons.account_circle_outlined,
                        size: context.adaptiveIconSize(
                          24,
                          tabletSize: 32,
                          largeTabletSize: 38,
                        ),
                      ),
                      tooltip: 'Sign In / Account',
                      onPressed: () => showAccountBottomSheet(context),
                    );
                  }
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (err, stack) => IconButton(
                  icon: const Icon(Icons.account_circle_outlined),
                  tooltip: 'Sign In / Account',
                  onPressed: () => showAccountBottomSheet(context),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButtonLocation: isWide
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: fabBottomPadding,
          right: isWide
              ? (context.adaptiveMargin > 16 ? context.adaptiveMargin - 16 : 0)
              : 0,
        ),
        child: _buildFloatingActions(context, isDark),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProjects,
          child: _projects.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: AdaptivePageContainer(
                    child: _buildEmptyState(context, isDark),
                  ),
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: AdaptivePageContainer(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search & Filter Bar
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.adaptiveMargin,
                          ),
                          child: _buildSearchAndFilterBar(context, isDark),
                        ),
                        const SizedBox(height: 18),

                        // Documents Section
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.adaptiveMargin,
                          ),
                          child: _buildProjectsSection(context, isDark),
                        ),

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFloatingActions(BuildContext context, bool isDark) {
    final pillHeight = context.adaptiveIconSize(
      52,
      tabletSize: 60,
      largeTabletSize: 68,
    );

    return Container(
      key: const Key('scan_floating_action_pill'),
      height: pillHeight,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(pillHeight / 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.38),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scan with Camera
            InkWell(
              onTap: _isProcessing ? null : _handleScanWithCamera,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(pillHeight / 2),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.isLargeTablet ? 24 : 18,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isProcessing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        Icons.camera_alt_rounded,
                        size: context.adaptiveIconSize(
                          20,
                          tabletSize: 24,
                          largeTabletSize: 28,
                        ),
                        color: Colors.white,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      'Scan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.adaptiveFontSize(
                          14,
                          tabletSize: 16,
                          largeTabletSize: 18,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Vertical Divider
            Container(
              height: pillHeight * 0.45,
              width: 1,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            // Import from Gallery
            InkWell(
              onTap: _isProcessing ? null : _handleImportFromGallery,
              borderRadius: BorderRadius.horizontal(
                right: Radius.circular(pillHeight / 2),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.isLargeTablet ? 24 : 18,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library_rounded,
                      size: context.adaptiveIconSize(
                        20,
                        tabletSize: 24,
                        largeTabletSize: 28,
                      ),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Gallery',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.adaptiveFontSize(
                          14,
                          tabletSize: 16,
                          largeTabletSize: 18,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: context.isLargeTablet ? 88 : 76,
              height: context.isLargeTablet ? 88 : 76,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.primaryContainerLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.document_scanner_rounded,
                size: context.adaptiveIconSize(
                  38,
                  tabletSize: 46,
                  largeTabletSize: 52,
                ),
                color: isDark ? AppColors.primaryLight : AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Documents Yet',
              style: TextStyle(
                fontSize: context.adaptiveFontSize(
                  18,
                  tabletSize: 22,
                  largeTabletSize: 24,
                ),
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Scan physical documents with your camera or import images to convert them into crisp PDFs.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: context.adaptiveFontSize(
                    13,
                    tabletSize: 15,
                    largeTabletSize: 16.5,
                  ),
                  height: 1.45,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _handleScanWithCamera,
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Scan Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _handleImportFromGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Import Images'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.white
                        : AppColors.textPrimaryLight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar(BuildContext context, bool isDark) {
    final barHeight = context.isLargeTablet
        ? 58.0
        : (context.isMediumOrWider ? 52.0 : 46.0);
    final barRadius = context.isLargeTablet ? 18.0 : 14.0;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceVariantDark
                  : AppColors.surfaceVariantLight,
              borderRadius: BorderRadius.circular(barRadius),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              style: TextStyle(
                fontSize: context.adaptiveFontSize(
                  13.5,
                  tabletSize: 16.5,
                  largeTabletSize: 18.5,
                ),
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: context.adaptiveIconSize(
                    20,
                    tabletSize: 24,
                    largeTabletSize: 28,
                  ),
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                hintText: 'Search documents, notes, etc...',
                hintStyle: TextStyle(
                  fontSize: context.adaptiveFontSize(
                    13,
                    tabletSize: 15.5,
                    largeTabletSize: 17.5,
                  ),
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: context.adaptiveIconSize(
                            18,
                            tabletSize: 22,
                            largeTabletSize: 26,
                          ),
                        ),
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showFilterBottomSheet(context),
            borderRadius: BorderRadius.circular(barRadius),
            child: Ink(
              width: barHeight,
              height: barHeight,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(barRadius),
                border: Border.all(
                  color: _sortBy != 'date_desc'
                      ? (isDark ? AppColors.primaryLight : AppColors.primary)
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.tune_rounded,
                  size: context.adaptiveIconSize(
                    20,
                    tabletSize: 24,
                    largeTabletSize: 28,
                  ),
                  color: _sortBy != 'date_desc'
                      ? (isDark ? AppColors.primaryLight : AppColors.primary)
                      : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sort Documents',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSortOption(
                  label: 'Newest first (Default)',
                  value: 'date_desc',
                  isDark: isDark,
                  onTap: () {
                    setState(() => _sortBy = 'date_desc');
                    Navigator.of(ctx).pop();
                  },
                ),
                _buildSortOption(
                  label: 'Oldest first',
                  value: 'date_asc',
                  isDark: isDark,
                  onTap: () {
                    setState(() => _sortBy = 'date_asc');
                    Navigator.of(ctx).pop();
                  },
                ),
                _buildSortOption(
                  label: 'Name (A-Z)',
                  value: 'name_asc',
                  isDark: isDark,
                  onTap: () {
                    setState(() => _sortBy = 'name_asc');
                    Navigator.of(ctx).pop();
                  },
                ),
                _buildSortOption(
                  label: 'File Size (Largest first)',
                  value: 'size_desc',
                  isDark: isDark,
                  onTap: () {
                    setState(() => _sortBy = 'size_desc');
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption({
    required String label,
    required String value,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isSelected = _sortBy == value;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                : (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_rounded,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
                size: 20,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildNoSearchResultsState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 10),
          Text(
            'No documents found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No documents matched "$_searchQuery"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsSection(BuildContext context, bool isDark) {
    final filtered = _filteredProjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Documents',
                style: TextStyle(
                  fontSize: context.adaptiveFontSize(
                    18,
                    tabletSize: 22,
                    largeTabletSize: 26,
                  ),
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${filtered.length} ${filtered.length == 1 ? 'doc' : 'docs'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (filtered.isEmpty)
          _buildNoSearchResultsState(isDark)
        else if (context.isMediumOrWider)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: context.responsiveValue(
                compact: 1,
                medium: 2,
                expanded: 2,
                large: 3,
              ),
              mainAxisExtent: context.isLargeTablet ? 128 : 112,
              crossAxisSpacing: context.isMediumOrWider ? 16 : 12,
              mainAxisSpacing: context.isMediumOrWider ? 16 : 12,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final project = filtered[index];
              return _buildProjectCard(context, project, isDark);
            },
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final project = filtered[index];
              return _buildProjectCard(context, project, isDark);
            },
          ),
      ],
    );
  }

  Future<void> _handleRenameProject(ScanProject project) async {
    final controller = TextEditingController(text: project.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document Name',
            hintText: 'e.g. Aadhaar Card, Bill, Invoice',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != project.name) {
      await _projectService.renameProject(project.id, newName);
      _loadProjects();
    }
  }

  Widget _buildProjectCard(
    BuildContext context,
    ScanProject project,
    bool isDark,
  ) {
    final sizeStr = _formatBytes(project.pdfSizeBytes);
    final dateStr = DateFormat('d MMM yyyy').format(project.updatedAt);
    final isSaved = _savedPdfPaths.contains(project.id);
    final coverFile = project.coverImagePath != null
        ? File(project.coverImagePath!)
        : null;

    final coverWidth = context.adaptiveIconSize(
      52,
      tabletSize: 66,
      largeTabletSize: 76,
    );
    final coverHeight = context.adaptiveIconSize(
      68,
      tabletSize: 86,
      largeTabletSize: 100,
    );
    final iconActionSize = context.adaptiveIconSize(
      22,
      tabletSize: 26,
      largeTabletSize: 30,
    );
    final actionBoxSize = context.isLargeTablet
        ? 48.0
        : (context.isMediumOrWider ? 42.0 : 36.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) =>
                      ScanProjectDetailScreen(initialProject: project),
                ),
              )
              .then((_) => _loadProjects());
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: EdgeInsets.all(context.isMediumOrWider ? 14 : 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Cover thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: coverWidth,
                  height: coverHeight,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceVariantDark
                        : AppColors.surfaceVariantLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  child: coverFile != null && coverFile.existsSync()
                      ? Image.file(
                          coverFile,
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppColors.primary,
                            size: context.adaptiveIconSize(
                              28,
                              tabletSize: 34,
                              largeTabletSize: 40,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.picture_as_pdf_rounded,
                          color: AppColors.primary,
                          size: context.adaptiveIconSize(
                            28,
                            tabletSize: 34,
                            largeTabletSize: 40,
                          ),
                        ),
                ),
              ),
              SizedBox(width: context.isMediumOrWider ? 14 : 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project.name,
                      style: TextStyle(
                        fontSize: context.adaptiveFontSize(
                          15.5,
                          tabletSize: 18.5,
                          largeTabletSize: 21,
                        ),
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.primaryContainerDark
                                : AppColors.primaryContainerLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${project.pageCount} ${project.pageCount == 1 ? 'Page' : 'Pages'}',
                            style: TextStyle(
                              fontSize: context.adaptiveFontSize(
                                11,
                                tabletSize: 13,
                                largeTabletSize: 14.5,
                              ),
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.primaryLight
                                  : AppColors.primaryDark,
                            ),
                          ),
                        ),
                        if (isSaved) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 11,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Saved',
                                  style: TextStyle(
                                    fontSize: context.adaptiveFontSize(
                                      10.5,
                                      tabletSize: 12,
                                      largeTabletSize: 13.5,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$dateStr  •  $sizeStr',
                      style: TextStyle(
                        fontSize: context.adaptiveFontSize(
                          11.5,
                          tabletSize: 14,
                          largeTabletSize: 16,
                        ),
                        fontWeight: FontWeight.normal,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // Single clean 3-dot popup menu
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: iconActionSize,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                constraints: BoxConstraints(
                  minWidth: actionBoxSize * 0.8,
                  minHeight: actionBoxSize,
                ),
                padding: const EdgeInsets.all(4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tooltip: 'More options',
                onSelected: (val) {
                  if (val == 'save') {
                    _handleSaveProjectPdf(project);
                  } else if (val == 'share') {
                    _handleShareProjectPdf(project);
                  } else if (val == 'send_to_pc') {
                    if (project.pdfPath != null) {
                      SendToPcSheet.show(
                        context,
                        filePaths: [project.pdfPath!],
                      );
                    }
                  } else if (val == 'rename') {
                    _handleRenameProject(project);
                  } else if (val == 'delete') {
                    _handleDeleteProject(project);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(
                          isSaved
                              ? Icons.check_circle_rounded
                              : Icons.download_rounded,
                          size: 18,
                          color: isSaved ? AppColors.success : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isSaved
                              ? 'Saved to Downloads'
                              : 'Save PDF to Downloads',
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Share PDF'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'send_to_pc',
                    child: Row(
                      children: [
                        Icon(
                          Icons.laptop_chromebook_rounded,
                          size: 18,
                          color: AppColors.secondary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Send to PC (Cyber Cafe)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Rename Document'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTipsBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Material(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 22,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Tips for Best PDF Scans',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTipRow(
                  isDark,
                  '📄',
                  'Contrast Background',
                  'Place white paper on a darker background for instant edge locking.',
                ),
                const SizedBox(height: 12),
                _buildTipRow(
                  isDark,
                  '💡',
                  'Good Lighting',
                  'Avoid direct flash; ambient lighting prevents reflections and shadows.',
                ),
                const SizedBox(height: 12),
                _buildTipRow(
                  isDark,
                  '📐',
                  'CamScanner Page Editor',
                  'Tap any document to replace blurry pages, rotate, or re-crop corners.',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTipRow(bool isDark, String emoji, String title, String detail) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: detail,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
