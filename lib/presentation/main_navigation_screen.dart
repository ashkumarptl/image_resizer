import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/image_source_picker_sheet.dart';
import '../core/constants/app_colors.dart';
import '../core/layout/adaptive_layout.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../services/in_app_update_service.dart';
import '../services/system_integration_service.dart';
import 'scan_to_pdf/scan_to_pdf_screen.dart';
import 'home/home_screen.dart';
import 'photo_stamp/photo_stamp_screen.dart';
import 'presets/presets_hub_screen.dart';
import 'settings/settings_screen.dart';
import 'signature/signature_cleaner_screen.dart';
import 'studio/image_studio_screen.dart';
import 'studio/widgets/studio_bottom_toolbar.dart';
import 'widgets/floating_bottom_nav_bar.dart';
import 'widgets/login_gate_dialog.dart';

final navigationIndexProvider = StateProvider<int>((ref) => 0);

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _sharedFileSub;
  StreamSubscription<String>? _shortcutSub;
  Timer? _updateTimer;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(navigationIndexProvider);
    _pageController = PageController(initialPage: initialIndex);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reapplySystemUiStyle();
      _checkForAppUpdate();
    });
    _initSystemIntegration();
  }

  void _checkForAppUpdate() {
    // Avoid running update timers during automated widget tests
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    // Delay slightly to let the first frame and animations settle
    _updateTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        InAppUpdateService.checkForUpdate(context: context);
      }
    });
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _reapplySystemUiStyle();
  }

  /// Android resets the system nav bar color when the app comes back from
  /// background (e.g. after switching apps or returning from a permission
  /// dialog). This observer reapplies the correct style on every resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reapplySystemUiStyle();
    }
  }

  void _reapplySystemUiStyle() {
    final themeMode = ref.read(themeModeProvider);
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);

    SystemChrome.setSystemUIOverlayStyle(
      isDark ? AppTheme.darkSystemUiStyle : AppTheme.lightSystemUiStyle,
    );
  }

  void _initSystemIntegration() {
    final service = SystemIntegrationService.instance;
    service.initialize();

    _sharedFileSub = service.onSharedFile.listen(_handleSharedFilePath);
    _shortcutSub = service.onShortcut.listen(_handleShortcut);

    // Handle cold start intents after initial UI render
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialSharedFile = await service.getInitialSharedFile();
      if (initialSharedFile != null && mounted) {
        _handleSharedFilePath(initialSharedFile);
        return;
      }

      final initialShortcut = await service.getInitialShortcut();
      if (initialShortcut != null && mounted) {
        _handleShortcut(initialShortcut);
        return;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _updateTimer?.cancel();
    _sharedFileSub?.cancel();
    _shortcutSub?.cancel();
    super.dispose();
  }

  void _handleSharedFilePath(String path) {
    if (!mounted) return;
    final file = File(path);
    if (!file.existsSync()) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageStudioScreen(initialImage: file),
      ),
    );
  }

  Future<void> _handleShortcut(String shortcut) async {
    if (!mounted) return;

    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final file = await ImageSourcePickerSheet.show(context);
    if (file == null || !mounted) return;

    switch (shortcut) {
      case 'quick_compress':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImageStudioScreen(
              initialImage: file,
              initialTool: StudioActiveTool.compress,
            ),
          ),
        );
        break;
      case 'clean_signature':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SignatureCleanerScreen(initialImage: file),
          ),
        );
        break;
      case 'photo_stamp':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PhotoStampScreen(initialImage: file),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);

    ref.listen<int>(navigationIndexProvider, (previous, next) {
      if (_pageController.hasClients) {
        final currentPage =
            _pageController.page?.round() ?? _pageController.initialPage;
        if (currentPage != next) {
          _pageController.animateToPage(
            next,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });

    final screens = [
      const HomeScreen(),
      const ScanToPdfScreen(isTab: true),
      const PresetsHubScreen(isTab: true),
      const SettingsScreen(isTab: true),
    ];

    const navItems = [
      FloatingNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      FloatingNavItem(
        icon: Icons.picture_as_pdf_outlined,
        activeIcon: Icons.picture_as_pdf_rounded,
        label: 'Scan to PDF',
      ),
      FloatingNavItem(
        icon: Icons.draw_outlined,
        activeIcon: Icons.draw_rounded,
        label: 'Exam Tools',
      ),
      FloatingNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Settings',
      ),
    ];

    final pageView = PageView(
      controller: _pageController,
      physics: const ClampingScrollPhysics(),
      onPageChanged: (index) {
        if (ref.read(navigationIndexProvider) != index) {
          HapticFeedback.selectionClick();
          ref.read(navigationIndexProvider.notifier).state = index;
        }
      },
      children: screens.map((screen) => _KeepAlivePage(child: screen)).toList(),
    );

    final isWide = context.isMediumOrWider;

    if (isWide) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Scaffold(
        extendBody: false,
        body: Row(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, railConstraints) {
                  final isShort = railConstraints.maxHeight < 460;
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: railConstraints.maxHeight),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          minWidth: isShort ? 64.0 : (context.screenWidth >= 1000 ? 104.0 : 88.0),
                          groupAlignment: isShort ? -1.0 : (context.isLargeTablet ? -0.4 : -0.6),
                          selectedIndex: currentIndex,
                          onDestinationSelected: (index) {
                            ref.read(navigationIndexProvider.notifier).state = index;
                          },
                          labelType: NavigationRailLabelType.all,
                          selectedIconTheme: IconThemeData(
                            size: context.isLargeTablet ? 34.0 : 28.0,
                            color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                          ),
                          unselectedIconTheme: IconThemeData(
                            size: context.isLargeTablet ? 34.0 : 28.0,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          selectedLabelTextStyle: GoogleFonts.outfit(
                            fontSize: context.isLargeTablet ? 15.0 : 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                          ),
                          unselectedLabelTextStyle: GoogleFonts.outfit(
                            fontSize: context.isLargeTablet ? 14.0 : 13.0,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          leading: Padding(
                            padding: EdgeInsets.only(
                              top: isShort ? 4 : (context.isLargeTablet ? 14 : 10),
                              bottom: isShort ? 8 : (context.isLargeTablet ? 24 : 18),
                            ),
                            child: Container(
                              width: isShort ? 36.0 : (context.isLargeTablet ? 60.0 : 52.0),
                              height: isShort ? 36.0 : (context.isLargeTablet ? 60.0 : 52.0),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(isShort ? 10 : (context.isLargeTablet ? 20 : 16)),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.photo_size_select_large_rounded,
                                  color: Colors.white,
                                  size: isShort ? 18.0 : (context.isLargeTablet ? 36.0 : 28.0),
                                ),
                              ),
                            ),
                          ),
                          destinations: [
                            NavigationRailDestination(
                              icon: const Icon(Icons.home_outlined),
                              selectedIcon: const Icon(Icons.home_rounded),
                              label: const Text('Home'),
                              padding: EdgeInsets.symmetric(vertical: context.isLargeTablet ? 12 : 6),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              selectedIcon: const Icon(Icons.picture_as_pdf_rounded),
                              label: const Text('Scan to PDF'),
                              padding: EdgeInsets.symmetric(vertical: context.isLargeTablet ? 12 : 6),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.draw_outlined),
                              selectedIcon: const Icon(Icons.draw_rounded),
                              label: const Text('Exam Tools'),
                              padding: EdgeInsets.symmetric(vertical: context.isLargeTablet ? 12 : 6),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.settings_outlined),
                              selectedIcon: const Icon(Icons.settings_rounded),
                              label: const Text('Settings'),
                              padding: EdgeInsets.symmetric(vertical: context.isLargeTablet ? 12 : 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            Expanded(
              child: pageView,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: pageView,
      bottomNavigationBar: FloatingBottomNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(navigationIndexProvider.notifier).state = index;
        },
        items: navItems,
      ),
    );
  }
}

/// Preserves the state of each screen inside [PageView] across slide transitions.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

