import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/repositories/history_repository.dart';
import '../../services/in_app_update_service.dart';
import '../../services/storage_service.dart';
import '../home/home_screen.dart';
import '../widgets/account_section.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/repositories/usage_limit_repository.dart';

/// Provider to manage automatic metadata (GPS & Camera info) stripping setting
class StripMetadataNotifier extends StateNotifier<bool> {
  static const String _key = 'pref_strip_metadata';

  StripMetadataNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? true;
    } catch (_) {}
  }

  Future<void> setStripMetadata(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }

  Future<void> toggle() async {
    await setStripMetadata(!state);
  }
}

final stripMetadataProvider = StateNotifierProvider<StripMetadataNotifier, bool>((ref) {
  return StripMetadataNotifier();
});

/// Provider to fetch app version and build number dynamically from platform metadata
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  } catch (e) {
    return '1.0.0+1';
  }
});


class SettingsScreen extends ConsumerStatefulWidget {
  final bool isTab;

  const SettingsScreen({
    super.key,
    this.isTab = false,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTapCount = 0;

  Future<void> _handleVersionTap() async {
    _versionTapCount++;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      await ref.read(developerModeProvider.notifier).toggle();
      final isDev = ref.read(developerModeProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDev
                ? '🛠️ Developer mode enabled: Limits bypassed!'
                : 'Developer mode disabled: Standard limits active.',
          ),
          backgroundColor: isDev ? AppColors.primary : AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (_versionTapCount >= 3) {
      final remaining = 7 - _versionTapCount;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are $remaining tap${remaining == 1 ? '' : 's'} away from toggling Developer Mode.'),
          duration: const Duration(milliseconds: 700),
        ),
      );
    }
  }

  Future<void> _handleClearCache() async {
    await StorageService.cleanOldCacheFiles(maxAge: Duration.zero);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🧹 Temporary processing cache cleared!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _handleClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text('This will remove all recent processed image references from the home screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(historyRepositoryProvider).clearHistory();
      ref.invalidate(recentHistoryProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('History cleared successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleOpenPrivacyPolicy() async {
    final Uri uri = Uri.parse(AppConstants.privacyPolicyUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Privacy Policy link'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening link: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: context.isLargeTablet ? 84 : (context.isMediumOrWider ? 72 : null),
        automaticallyImplyLeading: !widget.isTab,
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: context.adaptiveFontSize(20, tabletSize: 26, largeTabletSize: 28),
          ),
        ),
      ),
      body: SafeArea(
        child: AdaptivePageContainer(
          maxWidth: 1200,
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;

              if (isWide) {
                // Tablet Horizontal / Wide 2-Column Dashboard Layout
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    context.adaptiveMargin,
                    context.isMediumOrWider ? 24 : 20,
                    context.adaptiveMargin,
                    100,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Account, Appearance & About
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAccountSection(context, isDark),
                            SizedBox(height: context.isMediumOrWider ? 28 : 24),
                            _buildAppearanceSection(context, isDark, currentThemeMode),
                            SizedBox(height: context.isMediumOrWider ? 28 : 24),
                            _buildAboutSection(context, isDark),
                          ],
                        ),
                      ),
                      SizedBox(width: context.adaptiveMargin),
                      // Right Column: Storage, Privacy & Security
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStorageSection(context, isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Mobile / Portrait Single-Column Stacked Layout
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  context.adaptiveMargin,
                  20,
                  context.adaptiveMargin,
                  100,
                ),
                children: [
                  _buildAccountSection(context, isDark),
                  const SizedBox(height: 24),
                  _buildAppearanceSection(context, isDark, currentThemeMode),
                  const SizedBox(height: 24),
                  _buildStorageSection(context, isDark),
                  const SizedBox(height: 24),
                  _buildAboutSection(context, isDark),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'ACCOUNT', isDark: isDark),
        SizedBox(height: context.isMediumOrWider ? 14 : 10),
        const AccountSection(),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context, bool isDark, ThemeMode currentThemeMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'APPEARANCE', isDark: isDark),
        SizedBox(height: context.isMediumOrWider ? 14 : 10),
        Container(
          padding: EdgeInsets.all(context.isLargeTablet ? 24 : (context.isMediumOrWider ? 20 : 16)),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(context.isLargeTablet ? 20 : 16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App Theme',
                style: TextStyle(
                  fontSize: context.adaptiveFontSize(15, tabletSize: 18.5, largeTabletSize: 22),
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose light, dark, or follow your system settings.',
                style: TextStyle(
                  fontSize: context.adaptiveFontSize(12, tabletSize: 15, largeTabletSize: 17),
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              SizedBox(height: context.isLargeTablet ? 24 : (context.isMediumOrWider ? 20 : 16)),
              Row(
                children: [
                  _ThemeOptionCard(
                    title: 'System',
                    icon: Icons.brightness_auto,
                    isSelected: currentThemeMode == ThemeMode.system,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                  ),
                  SizedBox(width: context.isMediumOrWider ? 14 : 10),
                  _ThemeOptionCard(
                    title: 'Light',
                    icon: Icons.light_mode_rounded,
                    isSelected: currentThemeMode == ThemeMode.light,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                  ),
                  SizedBox(width: context.isMediumOrWider ? 14 : 10),
                  _ThemeOptionCard(
                    title: 'Dark',
                    icon: Icons.dark_mode_rounded,
                    isSelected: currentThemeMode == ThemeMode.dark,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStorageSection(BuildContext context, bool isDark) {
    final listTilePadding = EdgeInsets.symmetric(
      horizontal: context.isLargeTablet ? 24 : (context.isMediumOrWider ? 20 : 16),
      vertical: context.isLargeTablet ? 14 : (context.isMediumOrWider ? 8 : 2),
    );
    final leadingIconSize = context.adaptiveIconSize(24, tabletSize: 30, largeTabletSize: 38);
    final titleFontSize = context.adaptiveFontSize(14, tabletSize: 17.5, largeTabletSize: 20.5);
    final subtitleFontSize = context.adaptiveFontSize(12, tabletSize: 14.5, largeTabletSize: 16.5);
    final trailingIconSize = context.adaptiveIconSize(20, tabletSize: 24, largeTabletSize: 30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'STORAGE & PRIVACY', isDark: isDark),
        SizedBox(height: context.isMediumOrWider ? 14 : 10),
        Material(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.isLargeTablet ? 20 : 16),
            side: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: listTilePadding,
                secondary: Icon(Icons.shield_outlined, color: AppColors.primary, size: leadingIconSize),
                title: Text(
                  'Strip GPS & Camera Metadata',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: titleFontSize),
                ),
                subtitle: Text(
                  'Remove location and device info from files before upload',
                  style: TextStyle(fontSize: subtitleFontSize),
                ),
                value: ref.watch(stripMetadataProvider),
                onChanged: (val) => ref.read(stripMetadataProvider.notifier).setStripMetadata(val),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: listTilePadding,
                leading: Icon(Icons.cleaning_services_outlined, color: AppColors.primary, size: leadingIconSize),
                title: Text('Clear Temporary Cache', style: TextStyle(fontWeight: FontWeight.w600, fontSize: titleFontSize)),
                subtitle: Text('Remove temporary cached image files', style: TextStyle(fontSize: subtitleFontSize)),
                trailing: Icon(Icons.chevron_right, size: trailingIconSize),
                onTap: _handleClearCache,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: listTilePadding,
                leading: Icon(Icons.history_toggle_off_rounded, color: AppColors.warning, size: leadingIconSize),
                title: Text('Clear Recent History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: titleFontSize)),
                subtitle: Text('Clear history list on home screen', style: TextStyle(fontSize: subtitleFontSize)),
                trailing: Icon(Icons.chevron_right, size: trailingIconSize),
                onTap: _handleClearHistory,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: listTilePadding,
                leading: Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: leadingIconSize),
                title: Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: titleFontSize)),
                subtitle: Text('Read our data practices & policies', style: TextStyle(fontSize: subtitleFontSize)),
                trailing: Icon(Icons.open_in_new_rounded, size: context.adaptiveIconSize(18, tabletSize: 22, largeTabletSize: 24)),
                onTap: _handleOpenPrivacyPolicy,
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.all(context.isMediumOrWider ? 18 : 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: AppColors.success,
                      size: context.adaptiveIconSize(20, tabletSize: 26, largeTabletSize: 30),
                    ),
                    SizedBox(width: context.isMediumOrWider ? 14 : 10),
                    Expanded(
                      child: Text(
                        '100% Offline & Private. Images are processed exclusively on your device.',
                        style: TextStyle(
                          fontSize: context.adaptiveFontSize(12, tabletSize: 15, largeTabletSize: 16.5),
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context, bool isDark) {
    final aboutPadding = context.isMediumOrWider ? 20.0 : 16.0;
    final rowFontSize = context.adaptiveFontSize(14, tabletSize: 16.5, largeTabletSize: 18);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'ABOUT', isDark: isDark),
        SizedBox(height: context.isMediumOrWider ? 14 : 10),
        Container(
          padding: EdgeInsets.all(aboutPadding),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('App Name', style: TextStyle(fontSize: rowFontSize)),
                  ),
                  Flexible(
                    child: Text(
                      AppConstants.appName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: rowFontSize),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleVersionTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: context.isMediumOrWider ? 8 : 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Version', style: TextStyle(fontSize: rowFontSize)),
                        ),
                        ref.watch(appVersionProvider).when(
                              data: (version) => Flexible(
                                child: Text(
                                  version,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: rowFontSize),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              loading: () => SizedBox(
                                width: context.isMediumOrWider ? 18 : 14,
                                height: context.isMediumOrWider ? 18 : 14,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              ),
                              error: (_, _) => Flexible(
                                child: Text(
                                  '1.0.0+1',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: rowFontSize),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 20),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    InAppUpdateService.checkForUpdate(
                      context: context,
                      isManualCheck: true,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: context.isMediumOrWider ? 8 : 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Check for Updates',
                            style: TextStyle(fontSize: rowFontSize),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.system_update_alt_rounded,
                          size: context.adaptiveIconSize(18, tabletSize: 24, largeTabletSize: 28),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (ref.watch(isDeveloperProvider)) ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.terminal_rounded,
                            size: context.adaptiveIconSize(18, tabletSize: 24, largeTabletSize: 28),
                            color: AppColors.primary,
                          ),
                          SizedBox(width: context.isMediumOrWider ? 12 : 8),
                          Flexible(
                            child: Text(
                              'Developer Mode',
                              style: TextStyle(
                                fontSize: rowFontSize,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.isMediumOrWider ? 12 : 8,
                        vertical: context.isMediumOrWider ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Active (Limits Bypassed)',
                        style: TextStyle(
                          fontSize: context.adaptiveFontSize(11, tabletSize: 13.5, largeTabletSize: 15),
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: context.adaptiveFontSize(12, tabletSize: 15, largeTabletSize: 17),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: EdgeInsets.symmetric(vertical: context.isMediumOrWider ? 16 : 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.primaryContainerDark : AppColors.primaryContainerLight)
                  : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: context.adaptiveIconSize(22, tabletSize: 28, largeTabletSize: 32),
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
                SizedBox(height: context.isMediumOrWider ? 8 : 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: context.adaptiveFontSize(12, tabletSize: 15, largeTabletSize: 16.5),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? AppColors.textPrimaryDark : AppColors.primaryDark)
                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
