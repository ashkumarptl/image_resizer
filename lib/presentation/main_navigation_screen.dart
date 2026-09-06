import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../services/system_integration_service.dart';
import 'exam_tools/exam_tools_screen.dart';
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

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  StreamSubscription<String>? _sharedFileSub;
  StreamSubscription<String>? _shortcutSub;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initSystemIntegration();
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
      }
    });
  }

  @override
  void dispose() {
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

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked == null || !mounted) return;
    final file = File(picked.path);

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

    final screens = [
      const HomeScreen(),
      ExamToolsScreen(
        onNavigateToPresets: () {
          ref.read(navigationIndexProvider.notifier).state = 2;
        },
      ),
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
        icon: Icons.draw_outlined,
        activeIcon: Icons.draw_rounded,
        label: 'Exam Tools',
      ),
      FloatingNavItem(
        icon: Icons.tune_outlined,
        activeIcon: Icons.tune_rounded,
        label: 'Presets',
      ),
      FloatingNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Settings',
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
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
