import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/services/auth_service.dart';
import 'package:image_resizer/presentation/home/home_screen.dart';
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
      appName: 'Image Tools',
      packageName: 'com.example.image_resizer',
      version: '1.2.0',
      buildNumber: '3',
      buildSignature: '',
    );
  });

  Widget buildHomeScreen() {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(MockAuthService()),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  group('HomeScreen Adaptive Tablet Layout Tests', () {
    testWidgets('renders cleanly on Small Tablet (600x900dp)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Select Photo to Optimize'), findsOneWidget);
      expect(find.text('Single Photo'), findsOneWidget);
      expect(find.text('Batch (Multi)'), findsOneWidget);
      expect(find.text('Scan to PDF'), findsOneWidget);
      expect(find.text('Quick Utilities'), findsOneWidget);
    });

    testWidgets('renders single-column stacked hero cards on Medium Tablet Portrait (768x1024dp)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Select Photo to Optimize'), findsOneWidget);
      expect(find.text('Single Photo'), findsOneWidget);
      expect(find.text('Batch (Multi)'), findsOneWidget);
      expect(find.text('Scan to PDF'), findsOneWidget);

      // Verify single-column stacked layout (hero card above scan to pdf)
      final singlePhotoPos = tester.getCenter(find.text('Single Photo'));
      final scanToPdfPos = tester.getCenter(find.text('Scan to PDF'));
      expect(singlePhotoPos.dy, lessThan(scanToPdfPos.dy));
    });

    testWidgets('renders side-by-side hero cards on Large Display (1024x1366dp)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Select Photo to Optimize'), findsOneWidget);
      expect(find.text('Single Photo'), findsOneWidget);
      expect(find.text('Batch (Multi)'), findsOneWidget);
      expect(find.text('Scan Documents to PDF'), findsOneWidget);
      expect(find.text('Open Document Scanner'), findsOneWidget);
      expect(find.text('Quick Utilities'), findsOneWidget);
      expect(find.text('Signature'), findsOneWidget);
      expect(find.text('Photo Stamp'), findsOneWidget);
      expect(find.text('Deskew Doc'), findsOneWidget);

      // Verify side-by-side layout (horizontal)
      final singlePhotoPos = tester.getCenter(find.text('Single Photo'));
      final openScannerPos = tester.getCenter(find.text('Open Document Scanner'));
      expect(singlePhotoPos.dx, lessThan(openScannerPos.dx));
    });

    testWidgets('renders cleanly in single-column layout on 800x1280dp tablet screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Select Photo to Optimize'), findsOneWidget);
      expect(find.text('Single Photo'), findsOneWidget);
      expect(find.text('Batch (Multi)'), findsOneWidget);
      expect(find.text('Scan to PDF'), findsOneWidget);
      expect(find.text('Quick Utilities'), findsOneWidget);
      expect(find.text('Signature'), findsOneWidget);
      expect(find.text('Photo Stamp'), findsOneWidget);
      expect(find.text('Deskew Doc'), findsOneWidget);

      // Verify single-column stacked layout (hero card above scan to pdf card)
      final singlePhotoPos = tester.getCenter(find.text('Single Photo'));
      final scanToPdfPos = tester.getCenter(find.text('Scan to PDF'));
      expect(singlePhotoPos.dy, lessThan(scanToPdfPos.dy));
    });

    testWidgets('renders gracefully and adaptively on 1280x1880dp large display screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1880);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildHomeScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Select Photo to Optimize'), findsOneWidget);
      expect(find.text('Single Photo'), findsOneWidget);
      expect(find.text('Batch (Multi)'), findsOneWidget);
      expect(find.text('Scan Documents to PDF'), findsOneWidget);
      expect(find.text('Open Document Scanner'), findsOneWidget);
      expect(find.text('Quick Utilities'), findsOneWidget);
      expect(find.text('Signature'), findsOneWidget);
      expect(find.text('Photo Stamp'), findsOneWidget);
      expect(find.text('Deskew Doc'), findsOneWidget);

      // Verify side-by-side layout (since width 1280 >= 840)
      final singlePhotoPos = tester.getCenter(find.text('Single Photo'));
      final openScannerPos = tester.getCenter(find.text('Open Document Scanner'));
      expect(singlePhotoPos.dx, lessThan(openScannerPos.dx));
    });
  });
}
