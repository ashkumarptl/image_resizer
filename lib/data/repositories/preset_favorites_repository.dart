import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PresetFavoritesRepository {
  static const String _favoriteKey = 'pinned_preset_ids';
  static const String _recentKey = 'recent_preset_ids';

  final SharedPreferences? _prefsOverride;

  PresetFavoritesRepository({SharedPreferences? prefs}) : _prefsOverride = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefsOverride ?? await SharedPreferences.getInstance();
  }

  Future<Set<String>> loadFavoritePresetIds() async {
    try {
      final prefs = await _getPrefs();
      final list = prefs.getStringList(_favoriteKey) ?? [];
      return list.toSet();
    } catch (e) {
      debugPrint('[PresetFavoritesRepository] Error loading favorites: $e');
      return {};
    }
  }

  Future<bool> saveFavoritePresetIds(Set<String> ids) async {
    try {
      final prefs = await _getPrefs();
      return await prefs.setStringList(_favoriteKey, ids.toList());
    } catch (e) {
      debugPrint('[PresetFavoritesRepository] Error saving favorites: $e');
      return false;
    }
  }

  Future<List<String>> loadRecentPresetIds() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getStringList(_recentKey) ?? [];
    } catch (e) {
      debugPrint('[PresetFavoritesRepository] Error loading recents: $e');
      return [];
    }
  }

  Future<void> recordPresetUsed(String presetId) async {
    try {
      final prefs = await _getPrefs();
      final current = prefs.getStringList(_recentKey) ?? [];
      current.remove(presetId);
      current.insert(0, presetId);
      if (current.length > 10) {
        current.removeRange(10, current.length);
      }
      await prefs.setStringList(_recentKey, current);
    } catch (e) {
      debugPrint('[PresetFavoritesRepository] Error recording recent preset: $e');
    }
  }
}

final presetFavoritesRepositoryProvider = Provider<PresetFavoritesRepository>((ref) {
  return PresetFavoritesRepository();
});

class FavoritePresetIdsNotifier extends StateNotifier<Set<String>> {
  final PresetFavoritesRepository _repository;
  Future<void>? _loadFuture;

  FavoritePresetIdsNotifier(this._repository) : super({}) {
    load();
  }

  Future<void> load() {
    _loadFuture ??= _performLoad();
    return _loadFuture!;
  }

  Future<void> _performLoad() async {
    final ids = await _repository.loadFavoritePresetIds();
    if (mounted) {
      state = ids;
    }
  }

  Future<void> toggleFavorite(String presetId) async {
    if (_loadFuture != null) {
      await _loadFuture;
    }
    final updated = Set<String>.from(state);
    if (updated.contains(presetId)) {
      updated.remove(presetId);
    } else {
      updated.add(presetId);
    }
    if (mounted) {
      state = updated;
    }
    await _repository.saveFavoritePresetIds(updated);
  }

  bool isFavorite(String presetId) {
    return state.contains(presetId);
  }
}

final favoritePresetIdsProvider =
    StateNotifierProvider<FavoritePresetIdsNotifier, Set<String>>((ref) {
  final repo = ref.watch(presetFavoritesRepositoryProvider);
  return FavoritePresetIdsNotifier(repo);
});
