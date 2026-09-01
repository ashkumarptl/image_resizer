import 'package:firebase_core/firebase_core.dart';
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
    const ProviderScope(
      child: ImageToolsApp(),
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
      home: const HomeScreen(),
    );
  }
}
