import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'firebase_options.dart';
import 'presentation/main_navigation_screen.dart';
import 'services/analytics_service.dart';
import 'services/crashlytics_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable online font fetching so fonts are loaded 100% offline from bundled assets
  GoogleFonts.config.allowRuntimeFetching = false;

  // ── Apply correct system nav bar color BEFORE first frame ──────────────────
  // Without this, the OS shows its default (white) nav bar for a brief flash
  // even when the user has dark theme saved.
  await _applyInitialSystemUiStyle();

  // Initialize Firebase & Crashlytics
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await CrashlyticsService.initialize();
    await AnalyticsService.logAppOpen();
  } catch (e) {
    debugPrint('[Firebase] Initialization error: $e');
    // Still allow app to boot if offline or running in mock environment
  }

  // Clean old temporary cache files on startup
  StorageService.cleanOldCacheFiles();

  runApp(
    DevicePreview(
      enabled: !kReleaseMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS,
      builder: (context) => const ProviderScope(
        child: ImageToolsApp(),
      ),
    ),
  );
}

/// Reads the saved [ThemeMode] from SharedPreferences and immediately applies
/// the matching [SystemUiOverlayStyle] so the system navigation bar has the
/// right color before the first Flutter frame is drawn.
Future<void> _applyInitialSystemUiStyle() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(ThemeModeNotifier.themePrefKey);
    final savedMode = (savedIndex != null &&
            savedIndex >= 0 &&
            savedIndex < ThemeMode.values.length)
        ? ThemeMode.values[savedIndex]
        : ThemeMode.system;

    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final isDark = savedMode == ThemeMode.dark ||
        (savedMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);

    SystemChrome.setSystemUIOverlayStyle(
      isDark ? AppTheme.darkSystemUiStyle : AppTheme.lightSystemUiStyle,
    );
  } catch (_) {
    // Fallback: respect platform brightness if prefs unavailable
    final isDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? AppTheme.darkSystemUiStyle : AppTheme.lightSystemUiStyle,
    );
  }
}

class ImageToolsApp extends ConsumerWidget {
  const ImageToolsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeModeProvider);

    ref.listen<ThemeMode>(themeModeProvider, (previous, next) {
      final isDark = switch (next) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark,
      };
      SystemChrome.setSystemUIOverlayStyle(
        isDark ? AppTheme.darkSystemUiStyle : AppTheme.lightSystemUiStyle,
      );
    });

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: currentThemeMode,
      locale: DevicePreview.locale(context),
      builder: (context, child) {
        final previewChild = DevicePreview.appBuilder(context, child);
        final mediaQuery = MediaQuery.of(context);

        // Determine if the app is currently in dark mode
        final isDark = switch (currentThemeMode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        final overlayStyle = isDark
            ? AppTheme.darkSystemUiStyle
            : AppTheme.lightSystemUiStyle;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: mediaQuery.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.30,
              ),
            ),
            child: previewChild,
          ),
        );
      },
      home: const MainNavigationScreen(),
    );
  }
}
