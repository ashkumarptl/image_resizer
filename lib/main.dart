import 'dart:async';
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
import 'data/repositories/onboarding_repository.dart';
import 'firebase_options.dart';
import 'presentation/main_navigation_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'services/analytics_service.dart';
import 'services/crashlytics_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tune Flutter's decoded raster image cache to protect heap memory on budget devices
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20; // 80 MB
  PaintingBinding.instance.imageCache.maximumSize = 150; // Max 150 cached images

  // Disable online font fetching so fonts are loaded 100% offline from bundled assets
  GoogleFonts.config.allowRuntimeFetching = false;

  // Clean old temporary cache files in background without blocking cold-start frame
  unawaited(StorageService.cleanOldCacheFiles());

  // Concurrently initiate SharedPreferences and Firebase to minimize cold boot latency
  final prefsFuture = SharedPreferences.getInstance().then<SharedPreferences?>((p) => p).catchError((e) {
    debugPrint('[SharedPreferences] Init error: $e');
    return null;
  });

  final firebaseFuture = _initFirebaseSafely();

  // Await concurrent startup initializations
  final results = await Future.wait([prefsFuture, firebaseFuture]);
  final prefs = results[0] as SharedPreferences?;

  // Apply correct system nav bar color BEFORE first frame and obtain saved mode
  final savedThemeMode = _applyInitialSystemUiStyle(prefs);

  final initialOnboardingCompleted =
      prefs?.getBool(kPrefOnboardingCompletedKey) ?? false;

  runApp(
    DevicePreview(
      enabled:
          !kReleaseMode &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.macOS,
      builder: (context) => ProviderScope(
        overrides: [
          themeModeProvider.overrideWith(
            (ref) => ThemeModeNotifier(
              initialMode: savedThemeMode,
              prefs: prefs,
            ),
          ),
          onboardingCompletedProvider.overrideWith(
            (ref) => OnboardingNotifier(
              prefs: prefs,
              initialValue: initialOnboardingCompleted,
            ),
          ),
        ],
        child: const ImageToolsApp(),
      ),
    ),
  );
}

Future<void> _initFirebaseSafely() async {
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
}

/// Reads the saved [ThemeMode] from SharedPreferences and immediately applies
/// the matching [SystemUiOverlayStyle] so the system navigation bar has the
/// right color before the first Flutter frame is drawn. Returns the resolved [ThemeMode].
ThemeMode _applyInitialSystemUiStyle(SharedPreferences? prefs) {
  ThemeMode savedMode = ThemeMode.system;
  try {
    final savedIndex = prefs?.getInt(ThemeModeNotifier.themePrefKey);
    if (savedIndex != null &&
        savedIndex >= 0 &&
        savedIndex < ThemeMode.values.length) {
      savedMode = ThemeMode.values[savedIndex];
    }
  } catch (_) {}

  final platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  final isDark =
      savedMode == ThemeMode.dark ||
      (savedMode == ThemeMode.system &&
          platformBrightness == Brightness.dark);

  SystemChrome.setSystemUIOverlayStyle(
    isDark ? AppTheme.darkSystemUiStyle : AppTheme.lightSystemUiStyle,
  );

  return savedMode;
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

    final isOnboardingCompleted = ref.watch(onboardingCompletedProvider);

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
      home: isOnboardingCompleted
          ? const MainNavigationScreen()
          : const OnboardingScreen(isRevisit: false),
    );
  }
}
