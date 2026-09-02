import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_resizer/core/constants/app_constants.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/data/repositories/usage_limit_repository.dart';
import 'package:image_resizer/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends AuthService {
  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);

  @override
  User? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UsageLimitRepository & Providers Tests', () {
    test('Initial usage count is 0 and canUseFeature is true for guest', () async {
      final repo = UsageLimitRepository();
      final count = await repo.getUsageCount();
      expect(count, 0);

      final canUse = await repo.canUseFeature(isAuthenticated: false);
      expect(canUse, isTrue);
    });

    test('Incrementing reaches limit of maxFreeGuestUses (3)', () async {
      final repo = UsageLimitRepository();

      await repo.incrementUsage();
      expect(await repo.getUsageCount(), 1);
      expect(await repo.canUseFeature(isAuthenticated: false), isTrue);

      await repo.incrementUsage();
      expect(await repo.getUsageCount(), 2);
      expect(await repo.canUseFeature(isAuthenticated: false), isTrue);

      await repo.incrementUsage();
      expect(await repo.getUsageCount(), 3);
      // Now limit reached for unauthenticated user
      expect(await repo.canUseFeature(isAuthenticated: false), isFalse);

      // Authenticated user should always be allowed
      expect(await repo.canUseFeature(isAuthenticated: true), isTrue);
    });

    test('Resetting usage sets count back to 0', () async {
      final repo = UsageLimitRepository();
      await repo.incrementUsage();
      await repo.incrementUsage();
      await repo.incrementUsage();
      expect(await repo.getUsageCount(), 3);

      await repo.resetUsage();
      expect(await repo.getUsageCount(), 0);
      expect(await repo.canUseFeature(isAuthenticated: false), isTrue);
    });

    test('GuestUsageNotifier updates state properly with Riverpod container', () async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
      );
      addTearDown(container.dispose);

      // Initial state
      final initialCount = container.read(guestUsageCountProvider);
      expect(initialCount, 0);

      // Remaining uses
      expect(container.read(remainingFreeUsesProvider), AppConstants.maxFreeGuestUses);
      expect(container.read(isUsageLimitReachedProvider), isFalse);

      // Increment 3 times
      final notifier = container.read(guestUsageCountProvider.notifier);
      await notifier.increment();
      expect(container.read(guestUsageCountProvider), 1);
      expect(container.read(remainingFreeUsesProvider), 2);

      await notifier.increment();
      expect(container.read(guestUsageCountProvider), 2);
      expect(container.read(remainingFreeUsesProvider), 1);

      await notifier.increment();
      expect(container.read(guestUsageCountProvider), 3);
      expect(container.read(remainingFreeUsesProvider), 0);
      expect(container.read(isUsageLimitReachedProvider), isTrue);
    });
  });
}
