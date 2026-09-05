import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'firebase_options.dart';
import 'presentation/home/home_screen.dart';
import 'services/analytics_service.dart';
import 'services/crashlytics_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      enabled: !kReleaseMode,
      builder: (context) => const ProviderScope(
        child: ImageToolsApp(),
      ),
    ),
  );
}

class ImageToolsApp extends ConsumerWidget {
  const ImageToolsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeModeProvider);

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
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.30,
            ),
          ),
          child: previewChild,
        );
      },
      home: const HomeScreen(),
    );
  }
}
