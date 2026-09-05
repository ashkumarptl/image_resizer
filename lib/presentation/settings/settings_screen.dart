import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/repositories/history_repository.dart';
import '../../services/storage_service.dart';
import '../home/home_screen.dart';
import '../widgets/account_section.dart';
import '../../data/repositories/usage_limit_repository.dart';

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
  const SettingsScreen({super.key});

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
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. Account Section
            _SectionHeader(title: 'ACCOUNT', isDark: isDark),
            const SizedBox(height: 10),
            const AccountSection(),
            const SizedBox(height: 24),

            // 2. Appearance Section
            _SectionHeader(title: 'APPEARANCE', isDark: isDark),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
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
                  Text(
                    'App Theme',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose light, dark, or follow your system settings.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ThemeOptionCard(
                        title: 'System',
                        icon: Icons.brightness_auto,
                        isSelected: currentThemeMode == ThemeMode.system,
                        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                      ),
                      const SizedBox(width: 10),
                      _ThemeOptionCard(
                        title: 'Light',
                        icon: Icons.light_mode_rounded,
                        isSelected: currentThemeMode == ThemeMode.light,
                        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                      ),
                      const SizedBox(width: 10),
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
            const SizedBox(height: 24),

            // 2. Storage & Cache Section
            _SectionHeader(title: 'STORAGE & PRIVACY', isDark: isDark),
            const SizedBox(height: 10),
            Material(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined, color: AppColors.primary),
                    title: const Text('Clear Temporary Cache', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Remove temporary cached image files', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _handleClearCache,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history_toggle_off_rounded, color: AppColors.warning),
                    title: const Text('Clear Recent History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Clear history list on home screen', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _handleClearHistory,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                    title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Read our data practices & policies', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: _handleOpenPrivacyPolicy,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.security_rounded, color: AppColors.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '100% Offline & Private. Images are processed exclusively on your device.',
                            style: TextStyle(
                              fontSize: 12,
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
            const SizedBox(height: 24),

            // 3. About Section
            _SectionHeader(title: 'ABOUT', isDark: isDark),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
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
                      const Text('App Name', style: TextStyle(fontSize: 14)),
                      Text(AppConstants.appName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const Divider(height: 20),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleVersionTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Version', style: TextStyle(fontSize: 14)),
                            ref.watch(appVersionProvider).when(
                                  data: (version) => Text(
                                    version,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  loading: () => const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  error: (_, _) => const Text(
                                    '1.0.0+1',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
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
                        const Row(
                          children: [
                            Icon(Icons.terminal_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'Developer Mode',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Active (Limits Bypassed)',
                            style: TextStyle(
                              fontSize: 11,
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
        ),
      ),
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
        fontSize: 12,
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.primaryContainerDark : AppColors.primaryContainerLight)
                  : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
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
