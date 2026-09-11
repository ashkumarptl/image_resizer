import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/main_navigation_screen.dart';
import 'package:image_resizer/presentation/widgets/floating_bottom_nav_bar.dart';

void main() {
  testWidgets('FAB has exact 16-24dp clearance across all insets', (tester) async {
    for (final inset in [0.0, 16.0, 24.0, 34.0, 48.0]) {
      tester.view.physicalSize = const Size(476, 1024);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = FakeViewPadding(bottom: inset);
      tester.view.viewPadding = FakeViewPadding(bottom: inset);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
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

      final fabRect = tester.getRect(find.byType(FloatingActionButton));
      final navBarRect = tester.getRect(find.byType(FloatingBottomNavBar));
      final gap = navBarRect.top - fabRect.bottom;

      expect(gap, greaterThanOrEqualTo(16.0));
      expect(gap, lessThanOrEqualTo(28.0));
    }
  });
}
