import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import 'auth_repository.dart';

/// StateNotifier to manage manual developer mode toggle (persisted via SharedPreferences)
class DeveloperModeNotifier extends StateNotifier<bool> {
  static const String _prefKey = 'developer_mode_active';

  DeveloperModeNotifier() : super(_defaultState()) {
    _loadSavedState();
  }

  static bool _defaultState() {
    // Automatically enabled in debug mode when running the app (not in automated tests)
    final isTest = !kIsWeb && (Platform.environment['FLUTTER_TEST'] == 'true');
    return kDebugMode && !isTest;
  }

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefKey)) {
        state = prefs.getBool(_prefKey) ?? state;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    state = !state;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, state);
    } catch (_) {}
  }

  Future<void> setDeveloperMode(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }
}

/// Provider for DeveloperModeNotifier
final developerModeProvider = StateNotifierProvider<DeveloperModeNotifier, bool>((ref) {
  return DeveloperModeNotifier();
});

/// Provider to determine if the user has developer privileges.
/// When true:
/// - No trial limit banners are shown on HomeScreen
/// - No limit / trial expiration messages in Account section
/// - No login gate restrictions
/// - Guest usage counter is not incremented
final isDeveloperProvider = Provider<bool>((ref) {
  // 1. Check developer mode toggle / debug mode
  final isDevMode = ref.watch(developerModeProvider);
  if (isDevMode) return true;

  // 2. Check if logged in with developer email
  final user = ref.watch(currentUserProvider);
  if (user?.email != null) {
    const developerEmails = [
      'ashkumarptl@gmail.com',
    ];
    if (developerEmails.contains(user!.email!.toLowerCase().trim())) {
      return true;
    }
  }

  return false;
});

/// Provider for UsageLimitRepository
final usageLimitRepositoryProvider = Provider<UsageLimitRepository>((ref) {
  return UsageLimitRepository();
});

/// StateNotifier to manage reactive guest usage count
class GuestUsageNotifier extends StateNotifier<int> {
  final UsageLimitRepository _repository;

  GuestUsageNotifier(this._repository) : super(0) {
    _loadInitialCount();
  }

  Future<void> _loadInitialCount() async {
    state = await _repository.getUsageCount();
  }

  Future<void> increment() async {
    final newCount = await _repository.incrementUsage();
    state = newCount;
  }

  Future<void> reset() async {
    await _repository.resetUsage();
    state = 0;
  }
}

/// Provider for guest usage count state
final guestUsageCountProvider = StateNotifierProvider<GuestUsageNotifier, int>((ref) {
  final repo = ref.watch(usageLimitRepositoryProvider);
  return GuestUsageNotifier(repo);
});

/// Informative provider indicating if the user has reached their free trial limit
final isUsageLimitReachedProvider = Provider<bool>((ref) {
  final isDev = ref.watch(isDeveloperProvider);
  if (isDev) return false;

  final user = ref.watch(currentUserProvider);
  // Authenticated users have unlimited access
  if (user != null) return false;

  final count = ref.watch(guestUsageCountProvider);
  return count >= AppConstants.maxFreeGuestUses;
});

/// Remaining free uses count for guest
final remainingFreeUsesProvider = Provider<int>((ref) {
  final isDev = ref.watch(isDeveloperProvider);
  if (isDev) return -1; // -1 means unlimited

  final user = ref.watch(currentUserProvider);
  if (user != null) return -1; // -1 means unlimited

  final count = ref.watch(guestUsageCountProvider);
  final remaining = AppConstants.maxFreeGuestUses - count;
  return remaining > 0 ? remaining : 0;
});

class UsageLimitRepository {
  static const String _usageKey = 'guest_feature_usage_count';

  /// Get current guest usage count
  Future<int> getUsageCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_usageKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Increment usage count by 1 and return the updated count
  Future<int> incrementUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_usageKey) ?? 0;
      final updated = current + 1;
      await prefs.setInt(_usageKey, updated);
      return updated;
    } catch (_) {
      return 0;
    }
  }

  /// Reset usage count
  Future<void> resetUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_usageKey);
    } catch (_) {}
  }

  /// Check if user can use a feature
  Future<bool> canUseFeature({
    required bool isAuthenticated,
    bool isDeveloper = false,
  }) async {
    if (isAuthenticated || isDeveloper) return true;
    final count = await getUsageCount();
    return count < AppConstants.maxFreeGuestUses;
  }
}
