import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/presentation/main_navigation_screen.dart';
import 'package:image_resizer/presentation/widgets/floating_bottom_nav_bar.dart';
import 'package:image_resizer/services/auth_service.dart';

class MockAuthService extends AuthService {
  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);

  @override
  User? get currentUser => null;
}

void main() {
  testWidgets('FAB has exact 16-24dp clearance across all insets', (tester) async {
    for (final inset in [0.0, 16.0, 24.0, 34.0, 48.0]) {
      tester.view.physicalSize = const Size(476, 1024);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = FakeViewPadding(bottom: inset);
      tester.view.viewPadding = FakeViewPadding(bottom: inset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: const MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabFinder = find.descendant(
        of: find.byType(FloatingBottomNavBar),
        matching: find.text('Scan to PDF'),
      );
      await tester.tap(tabFinder);
      await tester.pumpAndSettle();

      final fabRect = tester.getRect(find.byKey(const Key('scan_floating_action_pill')));
      final navBarRect = tester.getRect(find.byType(FloatingBottomNavBar));
      final gap = navBarRect.top - fabRect.bottom;

      expect(gap, greaterThanOrEqualTo(16.0));
      expect(gap, lessThanOrEqualTo(28.0));
    }
  });
}
