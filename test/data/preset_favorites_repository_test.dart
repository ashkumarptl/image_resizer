import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/repositories/preset_favorites_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PresetFavoritesRepository Tests', () {
    test('loadFavoritePresetIds returns empty set when no presets are saved', () async {
      final repo = PresetFavoritesRepository();
      final favorites = await repo.loadFavoritePresetIds();
      expect(favorites, isEmpty);
    });

    test('loadFavoritePresetIds returns saved preset IDs', () async {
      SharedPreferences.setMockInitialValues({
        'pinned_preset_ids': ['ssc_photo', 'gate_photo'],
      });
      final repo = PresetFavoritesRepository();
      final favorites = await repo.loadFavoritePresetIds();
      expect(favorites, containsAll(['ssc_photo', 'gate_photo']));
      expect(favorites.length, 2);
    });

    test('saveFavoritePresetIds persists set to SharedPreferences', () async {
      final repo = PresetFavoritesRepository();
      final saved = await repo.saveFavoritePresetIds({'upsc_photo', 'neet_passport_photo'});
      expect(saved, isTrue);

      final loaded = await repo.loadFavoritePresetIds();
      expect(loaded, containsAll(['upsc_photo', 'neet_passport_photo']));
    });

    test('recordPresetUsed maintains recent preset order and limits to 10', () async {
      final repo = PresetFavoritesRepository();
      for (int i = 0; i < 15; i++) {
        await repo.recordPresetUsed('preset_$i');
      }

      final recents = await repo.loadRecentPresetIds();
      expect(recents.length, 10);
      expect(recents.first, 'preset_14');
    });
  });

  group('FavoritePresetIdsNotifier & Provider Tests', () {
    test('loads initial favorites and notifies when toggled', () async {
      SharedPreferences.setMockInitialValues({
        'pinned_preset_ids': ['ssc_photo'],
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(favoritePresetIdsProvider.notifier);
      await notifier.load();

      var state = container.read(favoritePresetIdsProvider);
      expect(state.contains('ssc_photo'), isTrue);

      // Toggle new preset
      await container.read(favoritePresetIdsProvider.notifier).toggleFavorite('gate_photo');

      state = container.read(favoritePresetIdsProvider);
      expect(state.contains('gate_photo'), isTrue);
      expect(state.contains('ssc_photo'), isTrue);

      // Toggle off ssc_photo
      await container.read(favoritePresetIdsProvider.notifier).toggleFavorite('ssc_photo');

      state = container.read(favoritePresetIdsProvider);
      expect(state.contains('ssc_photo'), isFalse);
      expect(state.contains('gate_photo'), isTrue);
      expect(container.read(favoritePresetIdsProvider.notifier).isFavorite('gate_photo'), isTrue);
    });
  });
}
