import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/services/auth_service.dart';

class MockAuthService extends AuthService {
  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);

  @override
  User? get currentUser => null;
}

void main() {
  group('Auth Tests', () {
    test('authServiceProvider creates instance of AuthService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authService = container.read(authServiceProvider);
      expect(authService, isA<AuthService>());
    });

    test('authStateProvider and currentUserProvider work with mock service', () async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
      );
      addTearDown(container.dispose);

      final user = container.read(currentUserProvider);
      expect(user, isNull);
    });
  });
}
