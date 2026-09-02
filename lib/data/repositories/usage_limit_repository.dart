import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import 'auth_repository.dart';

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
  final user = ref.watch(currentUserProvider);
  // Authenticated users have unlimited access
  if (user != null) return false;

  final count = ref.watch(guestUsageCountProvider);
  return count >= AppConstants.maxFreeGuestUses;
});

/// Remaining free uses count for guest
final remainingFreeUsesProvider = Provider<int>((ref) {
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
  Future<bool> canUseFeature({required bool isAuthenticated}) async {
    if (isAuthenticated) return true;
    final count = await getUsageCount();
    return count < AppConstants.maxFreeGuestUses;
  }
}
