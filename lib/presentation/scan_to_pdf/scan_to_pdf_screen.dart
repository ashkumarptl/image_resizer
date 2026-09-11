import 'dart:io';
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
import '../../services/scanner/document_scanner_service.dart';
import '../../services/scanner/scan_project_service.dart';
import '../../services/storage_service.dart';
import '../widgets/account_section.dart';
import '../widgets/login_gate_dialog.dart';
import 'scan_project_detail_screen.dart';

class ScanToPdfScreen extends ConsumerStatefulWidget {
  final bool isTab;
  final List<ScanProject>? initialProjects;

  const ScanToPdfScreen({
    super.key,
    this.isTab = false,
    this.initialProjects,
  });

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
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ScanProjectDetailScreen(initialProject: project),
            ),
          ).then((_) => _loadProjects());
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ScanProjectDetailScreen(initialProject: project),
          ),
        ).then((_) => _loadProjects());
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

    return Scaffold(
      key: const ValueKey("scan_to_pdf_scaffold"),
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isTab,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan to PDF',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Auto-deskew, enhance & convert to PDF',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          // Offline Status Badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.success.withValues(alpha: 0.16)
                  : AppColors.successContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.secondaryLight : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
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
                        radius: 14,
                        backgroundColor: AppColors.primaryContainerLight,
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null
                            ? Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              )
                            : null,
                      ),
                    );
                  } else {
                    return IconButton(
                      icon: const Icon(Icons.account_circle_outlined),
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
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: (widget.isTab && !isWide) ? 96 : 24,
          right: isWide ? (context.adaptiveMargin > 16 ? context.adaptiveMargin - 16 : 0) : 0,
        ),
        child: _buildNewScanFab(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProjects,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: AdaptivePageContainer(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Quick Action Cards ("Scan Document" and "Import Images")
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                    child: _buildQuickActionCards(context, isDark),
                  ),
                  const SizedBox(height: 16),

                  // 2. Search & Filter Bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                    child: _buildSearchAndFilterBar(context, isDark),
                  ),
                  const SizedBox(height: 20),

                  // 3. Documents & Projects Section
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                    child: _buildProjectsSection(context, isDark),
                  ),
                  const SizedBox(height: 24),

                  // 4. Features Row
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                    child: _buildFeatureChips(isDark),
                  ),
                  const SizedBox(height: 24),

                  // 5. Tips Card
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                    child: _buildTipsCard(context, isDark),
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

  Widget _buildFeatureChips(bool isDark) {
    final chips = [
      ('⚡ Auto Boundary', Colors.amber),
      ('🌓 Shadow Clean', Colors.teal),
      ('📑 Multi-Page PDF', const Color(0xFF6366F1)),
      ('🔒 100% Offline', Colors.green),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Text(
            item.$1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNewScanFab(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
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
        child: InkWell(
          onTap: _isProcessing ? null : _handleScanWithCamera,
          customBorder: const CircleBorder(),
          child: Center(
            child: _isProcessing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_rounded, size: 25, color: Colors.white),
                      SizedBox(height: 2),
                      Text(
                        'New Scan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCards(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            isDark: isDark,
            icon: Icons.photo_camera_rounded,
            iconBg: isDark ? AppColors.primaryContainerDark : AppColors.primaryContainerLight,
            iconColor: isDark ? AppColors.primaryLight : AppColors.primary,
            title: 'Scan\nDocument',
            onTap: _isProcessing ? null : _handleScanWithCamera,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            isDark: isDark,
            icon: Icons.photo_library_rounded,
            iconBg: isDark ? AppColors.secondaryContainerDark : AppColors.secondaryContainerLight,
            iconColor: isDark ? AppColors.secondaryLight : AppColors.secondary,
            title: 'Import\nImages',
            onTap: _isProcessing ? null : _handleImportFromGallery,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required bool isDark,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
              borderRadius: BorderRadius.circular(14),
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
                fontSize: 13.5,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                hintText: 'Search documents, notes, etc...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _sortBy != 'date_desc'
                      ? (isDark ? AppColors.primaryLight : AppColors.primary)
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: _sortBy != 'date_desc'
                      ? (isDark ? AppColors.primaryLight : AppColors.primary)
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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
                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_rounded, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 20)
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
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 10),
          Text(
            'No documents found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No documents matched "$_searchQuery"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
                'Documents & Projects',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${filtered.length} ${filtered.length == 1 ? 'doc' : 'docs'}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_projects.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      size: 28,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No scan projects yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Turn physical documents, receipts & forms into crisp, multi-page PDF files.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _handleScanWithCamera,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_rounded, size: 18),
                          label: Text(
                            _isProcessing ? 'Processing...' : 'Scan with Camera',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _handleImportFromGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text(
                          'Gallery',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else if (filtered.isEmpty)
          _buildNoSearchResultsState(isDark)
        else if (context.isMediumOrWider)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: context.responsiveValue(compact: 1, medium: 2, expanded: 2, large: 3),
              mainAxisExtent: 122,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
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

  Widget _buildProjectCard(BuildContext context, ScanProject project, bool isDark) {
    final sizeStr = _formatBytes(project.pdfSizeBytes);
    final dateStr = DateFormat('d MMM yyyy').format(project.updatedAt);
    final isSaved = _savedPdfPaths.contains(project.id);
    final coverFile = project.coverImagePath != null ? File(project.coverImagePath!) : null;

    final qualityLabel = PdfQualityPreset.fromString(project.pdfQuality).label.split(' ').first;
    final (qualityBg, qualityText) = switch (project.pdfQuality) {
      'high' => (
        isDark ? AppColors.error.withValues(alpha: 0.20) : AppColors.errorContainer,
        isDark ? const Color(0xFFFCA5A5) : AppColors.error,
      ),
      'low' => (
        isDark ? AppColors.warning.withValues(alpha: 0.20) : AppColors.warningContainer,
        isDark ? const Color(0xFFFDBA74) : AppColors.warning,
      ),
      _ => (
        isDark ? AppColors.secondaryContainerDark : AppColors.secondaryContainerLight,
        isDark ? AppColors.secondaryLight : AppColors.secondaryDark,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ScanProjectDetailScreen(initialProject: project),
            ),
          ).then((_) => _loadProjects());
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Cover thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52,
                  height: 68,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: coverFile != null && coverFile.existsSync()
                      ? Image.file(
                          coverFile,
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 28),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project.name,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.primaryContainerDark
                                : AppColors.primaryContainerLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${project.pageCount} ${project.pageCount == 1 ? 'Page' : 'Pages'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: qualityBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            qualityLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: qualityText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$dateStr  •  $sizeStr',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // Quick Actions (compact to avoid overflow on smaller screens)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isSaved ? Icons.check_circle_rounded : Icons.download_rounded,
                      size: 20,
                      color: isSaved ? AppColors.success : null,
                    ),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _handleSaveProjectPdf(project),
                    tooltip: isSaved ? 'Saved to Downloads' : 'Save PDF to Downloads',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 19),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _handleShareProjectPdf(project),
                    tooltip: 'Share PDF',
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 36),
                    padding: const EdgeInsets.all(4),
                    tooltip: 'More options',
                    onSelected: (val) {
                      if (val == 'rename') {
                        _handleRenameProject(project);
                      } else if (val == 'delete') {
                        _handleDeleteProject(project);
                      }
                    },
                    itemBuilder: (ctx) => [
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
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                            SizedBox(width: 10),
                            Text('Delete', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 20,
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tips for Best PDF Scans',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipRow(
            isDark,
            '📄',
            'Contrast Background',
            'Place white paper on a darker background for instant edge locking.',
          ),
          const SizedBox(height: 8),
          _buildTipRow(
            isDark,
            '💡',
            'Good Lighting',
            'Avoid direct flash; ambient lighting prevents reflections and shadows.',
          ),
          const SizedBox(height: 8),
          _buildTipRow(
            isDark,
            '📐',
            'CamScanner Page Editor',
            'Tap any document to replace blurry pages, rotate, or re-crop corners.',
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(
    bool isDark,
    String emoji,
    String title,
    String detail,
  ) {
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
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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
