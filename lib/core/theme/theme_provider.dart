import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String themePrefKey = 'image_tools_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadSavedTheme();
  }

  static void applySystemUiOverlay(ThemeMode mode) {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && platformBrightness == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? AppTheme.darkSystemUiStyle : AppTheme.lightSystemUiStyle,
    );
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt(themePrefKey);
      if (savedIndex != null && savedIndex >= 0 && savedIndex < ThemeMode.values.length) {
        state = ThemeMode.values[savedIndex];
        applySystemUiOverlay(state);
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    applySystemUiOverlay(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(themePrefKey, mode.index);
    } catch (_) {}
  }
}
