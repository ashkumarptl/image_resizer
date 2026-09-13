import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/presentation/settings/settings_screen.dart';
import 'package:image_resizer/services/auth_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
    PackageInfo.setMockInitialValues(
      appName: 'Image Resizer',
      packageName: 'com.ashspark.image_resizer',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Widget buildSettingsScreen() {
    return ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(MockAuthService())],
      child: const MaterialApp(home: SettingsScreen(isTab: true)),
    );
  }

  group('SettingsScreen Responsive Layout Tests', () {
    testWidgets('mobile layout (< 720dp) renders single-column ListView', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600); // 400x800 logical dp
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      // Verify top sections exist
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);

      // Verify single column ListView is used
      expect(find.byType(ListView), findsOneWidget);

      // Verify theme options are present
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Scroll to reveal lower sections in ListView
      await tester.scrollUntilVisible(find.text('ABOUT'), 300);
      await tester.pumpAndSettle();

      expect(find.text('STORAGE & PRIVACY'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('Strip GPS & Camera Metadata'), findsOneWidget);
      expect(find.text('Clear Temporary Cache'), findsOneWidget);
      expect(find.text('Clear Recent History'), findsOneWidget);
    });

    testWidgets(
      'tablet horizontal / wide layout (>= 720dp) renders 2-column dashboard layout',
      (WidgetTester tester) async {
        // 1800 x 1200 with DPR 1.5 = 1200 x 800 logical dp (tablet horizontal)
        tester.view.physicalSize = const Size(1800, 1200);
        tester.view.devicePixelRatio = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        // Verify sections exist in 2-column layout (all visible simultaneously)
        expect(find.text('ACCOUNT'), findsOneWidget);
        expect(find.text('APPEARANCE'), findsOneWidget);
        expect(find.text('STORAGE & PRIVACY'), findsOneWidget);
        expect(find.text('ABOUT'), findsOneWidget);

        // In wide mode, it uses SingleChildScrollView with Row of 2 columns instead of ListView
        expect(find.byType(ListView), findsNothing);
        expect(find.byType(SingleChildScrollView), findsOneWidget);

        // Verify privacy & security badge in right column
        expect(find.textContaining('100% Offline & Private'), findsOneWidget);

        // Verify no assertion or overflow occurred
        expect(tester.takeException(), isNull);
      },
    );
  });
}
