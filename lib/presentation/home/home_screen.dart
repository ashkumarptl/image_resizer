import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/history_item.dart';
import '../../data/models/process_result.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/usage_limit_repository.dart';
import '../batch/batch_screen.dart';
import '../perspective_crop/perspective_crop_screen.dart';
import '../photo_stamp/photo_stamp_screen.dart';
import '../result/result_screen.dart';
import '../signature/signature_cleaner_screen.dart';
import '../studio/image_studio_screen.dart';
import '../widgets/account_section.dart';
import '../widgets/bouncy_tap.dart';
import '../widgets/image_source_picker_sheet.dart';
import '../widgets/login_gate_dialog.dart';
import 'widgets/recent_files_section.dart';
import '../main_navigation_screen.dart';

final recentHistoryProvider = FutureProvider.autoDispose<List<HistoryItem>>((ref) async {
  return ref.watch(historyRepositoryProvider).getRecentHistory();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<File?> _pickImage({String title = 'Select Image Source'}) async {
    return ImageSourcePickerSheet.show(context, title: title);
  }

  Future<void> _handleStudioTool() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageStudioScreen(initialImage: file),
      ),
    );
  }

  Future<void> _handleBatchTool() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BatchScreen(),
      ),
    );
  }

  Future<void> _handleSignatureTool() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignatureCleanerScreen(initialImage: file),
      ),
    );
  }

  Future<void> _handlePhotoStampTool() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoStampScreen(initialImage: file),
      ),
    );
  }

  Future<void> _handlePerspectiveCropTool() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final file = await _pickImage(title: 'Select Document / Photo to Deskew');
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerspectiveCropScreen(initialImage: file),
      ),
    );
  }

  Future<void> _handleScanToPdfTool() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    ref.read(navigationIndexProvider.notifier).state = 1;
  }

  void _handleHistoryItemTap(HistoryItem item) {
    final originalFile = File(item.originalPath.isNotEmpty ? item.originalPath : item.filePath);

    final dummyResult = ProcessResult(
      originalPath: originalFile.path,
      outputPath: item.filePath,
      originalSizeBytes: item.originalSizeBytes,
      outputSizeBytes: item.outputSizeBytes,
      originalWidth: item.width,
      originalHeight: item.height,
      outputWidth: item.width,
      outputHeight: item.height,
      outputFormat: item.format,
      finalQuality: 85,
      processingTime: Duration.zero,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: dummyResult),
      ),
    );
  }

  Future<void> _handleClearHistory() async {
    await ref.read(historyRepositoryProvider).clearHistory();
    ref.invalidate(recentHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyAsync = ref.watch(recentHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppConstants.appName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recentHistoryProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: AdaptivePageContainer(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Guest Usage Trial Banner
                  _buildGuestUsageBanner(context, isDark),

                  // 1 & 2. Hero Pick & Scan to PDF Cards (Side-by-side on desktop/wide landscape)
                  if (context.screenWidth >= 960) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildHeroPickCard(context, isDark, withoutOuterPadding: true),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildScanToPdfCard(
                                context,
                                isDark,
                                withoutOuterPadding: true,
                                isWideMode: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    // Mobile stacked layout
                    _buildHeroPickCard(context, isDark),
                    const SizedBox(height: 16),
                    _buildScanToPdfCard(context, isDark),
                    const SizedBox(height: 20),
                  ],

                  // 3. Streamlined Quick Utilities (3 items)
                  _buildQuickUtilitiesSection(context, isDark),
                  const SizedBox(height: 22),

                  // 3. Recent Processed Files Section
                  historyAsync.when(
                    data: (historyList) => RecentFilesSection(
                      historyItems: historyList,
                      onItemTap: _handleHistoryItemTap,
                      onClearHistory: _handleClearHistory,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPickCard(BuildContext context, bool isDark, {bool withoutOuterPadding = false}) {
    final card = RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.borderDark
                : AppColors.primary.withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black26
                  : AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icon with soft halo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              'Select Photo to Optimize',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),

            // Subtitle
            Text(
              'Compress size, crop framing, or convert format',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: BouncyTap(
                    onTap: _handleStudioTool,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Single Photo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BouncyTap(
                    onTap: _handleBatchTool,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceVariantDark
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.copy_all_rounded,
                            size: 16,
                            color: isDark ? AppColors.textPrimaryDark : const Color(0xFF334155),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Batch (Multi)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isDark ? AppColors.textPrimaryDark : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (withoutOuterPadding) return card;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
      child: card,
    );
  }

  Widget _buildScanToPdfCard(
    BuildContext context,
    bool isDark, {
    bool withoutOuterPadding = false,
    bool isWideMode = false,
  }) {
    final Widget card;

    if (isWideMode) {
      card = RepaintBoundary(
        child: Material(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: _handleScanToPdfTool,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark
                      : AppColors.primary.withValues(alpha: 0.18),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black26
                        : AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(
                        alpha: isDark ? 0.22 : 0.1,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      size: 28,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Scan Documents to PDF',
                        style: TextStyle(
                          fontSize: isWideMode ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.secondaryContainerDark
                              : AppColors.secondaryContainerLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'DOCS',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.secondaryLight
                                : AppColors.secondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Multi-page scanner, auto-deskew & PDF export',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 18),
                  BouncyTap(
                    onTap: _handleScanToPdfTool,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Open Document Scanner',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      card = Material(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _handleScanToPdfTool,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.borderDark
                    : AppColors.primary.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black26
                      : AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.22 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Scan to PDF',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.secondaryContainerDark
                                  : AppColors.secondaryContainerLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'DOCS',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.secondaryLight
                                    : AppColors.secondaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Camera scanner, multi-page document & PDF export',
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
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.18 : 0.08,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (withoutOuterPadding) return card;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
      child: card,
    );
  }

  Widget _buildQuickUtilitiesSection(BuildContext context, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Utilities',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              InkWell(
                onTap: () {
                  ref.read(navigationIndexProvider.notifier).state = 2;
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Exam Hub',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickUtilityTile(
                  title: 'Signature',
                  subtitle: 'Clean B&W',
                  icon: Icons.draw_rounded,
                  accentColor: const Color(0xFF0D9488),
                  isDark: isDark,
                  onTap: _handleSignatureTool,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickUtilityTile(
                  title: 'Photo Stamp',
                  subtitle: 'Name & Date',
                  icon: Icons.badge_rounded,
                  accentColor: const Color(0xFF6366F1),
                  isDark: isDark,
                  onTap: _handlePhotoStampTool,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickUtilityTile(
                  title: 'Deskew Doc',
                  subtitle: 'Straighten ID',
                  icon: Icons.crop_rotate_rounded,
                  accentColor: const Color(0xFFEA580C),
                  isDark: isDark,
                  onTap: _handlePerspectiveCropTool,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuestUsageBanner(BuildContext context, bool isDark) {
    final isDeveloper = ref.watch(isDeveloperProvider);
    if (isDeveloper) {
      return const SizedBox.shrink();
    }

    final user = ref.watch(currentUserProvider);
    if (user != null) {
      return const SizedBox.shrink();
    }

    final usageCount = ref.watch(guestUsageCountProvider);
    final remaining = (AppConstants.maxFreeGuestUses - usageCount).clamp(0, AppConstants.maxFreeGuestUses);
    final isLimitReached = usageCount >= AppConstants.maxFreeGuestUses;

    return Padding(
      padding: EdgeInsets.fromLTRB(context.adaptiveMargin, 0, context.adaptiveMargin, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isLimitReached) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => const LoginGateBottomSheet(),
              );
            } else {
              showAccountBottomSheet(context);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLimitReached
                    ? [
                        AppColors.error.withValues(alpha: isDark ? 0.25 : 0.12),
                        AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.08),
                      ]
                    : [
                        AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.1),
                        AppColors.primaryDark.withValues(alpha: isDark ? 0.15 : 0.05),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLimitReached
                    ? AppColors.error.withValues(alpha: 0.5)
                    : AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLimitReached
                        ? AppColors.error.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLimitReached ? Icons.lock_outline_rounded : Icons.bolt_rounded,
                    size: 20,
                    color: isLimitReached ? AppColors.error : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLimitReached
                            ? 'Free Limit Reached (${AppConstants.maxFreeGuestUses}/${AppConstants.maxFreeGuestUses} used)'
                            : 'Free Trial: $remaining of ${AppConstants.maxFreeGuestUses} uses remaining',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isLimitReached
                              ? (isDark ? Colors.red.shade300 : AppColors.error)
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLimitReached
                            ? 'Sign in with Google for unlimited access'
                            : 'Sign in to unlock unlimited usage & presets',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLimitReached ? AppColors.error : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isLimitReached ? 'Sign In' : 'Unlock',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickUtilityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickUtilityTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.22 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
