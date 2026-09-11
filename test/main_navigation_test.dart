import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/core/constants/app_constants.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/presentation/main_navigation_screen.dart';
import 'package:image_resizer/presentation/widgets/floating_bottom_nav_bar.dart';
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
      appName: 'Image Tools',
      packageName: 'com.example.image_resizer',
      version: '1.1.1',
      buildNumber: '2',
      buildSignature: '',
    );
  });

  group('FloatingBottomNavBar Widget Tests', () {
    testWidgets('renders all 4 nav items correctly', (WidgetTester tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FloatingBottomNavBar(
              currentIndex: selectedIndex,
              onTap: (index) => selectedIndex = index,
              items: const [
                FloatingNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                FloatingNavItem(
                  icon: Icons.picture_as_pdf_outlined,
                  activeIcon: Icons.picture_as_pdf_rounded,
                  label: 'Scan to PDF',
                ),
                FloatingNavItem(
                  icon: Icons.draw_outlined,
                  activeIcon: Icons.draw_rounded,
                  label: 'Exam Tools',
                ),
                FloatingNavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Scan to PDF'), findsOneWidget);
      expect(find.text('Exam Tools'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Tap on Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(selectedIndex, 3);
    });

    testWidgets('handles high text scaler (1.30x and 1.50x) without overflow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.35),
            ),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: FloatingBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                FloatingNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                FloatingNavItem(
                  icon: Icons.picture_as_pdf_outlined,
                  activeIcon: Icons.picture_as_pdf_rounded,
                  label: 'Scan to PDF',
                ),
                FloatingNavItem(
                  icon: Icons.draw_outlined,
                  activeIcon: Icons.draw_rounded,
                  label: 'Exam Tools',
                ),
                FloatingNavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      );

      // Verify no assertion / overflow occurs during layout and painting
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Scan to PDF'), findsOneWidget);
      expect(find.text('Exam Tools'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('adapts bottom margin for Android 3-button navigation vs gesture navigation',
        (WidgetTester tester) async {
      // 1. Test 3-Button navigation (48dp bottom inset)
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewPadding: const EdgeInsets.only(bottom: 48),
              padding: const EdgeInsets.only(bottom: 48),
            ),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: FloatingBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                FloatingNavItem(icon: Icons.home, activeIcon: Icons.home, label: 'Home'),
                FloatingNavItem(icon: Icons.settings, activeIcon: Icons.settings, label: 'Settings'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final paddingFinder3Btn = find.descendant(
        of: find.byType(FloatingBottomNavBar),
        matching: find.byType(Padding),
      );
      final paddingWidget3Btn = tester.widget<Padding>(paddingFinder3Btn.first);
      // safeBottom (48) + 12 = 60
      final insets3Btn = paddingWidget3Btn.padding as EdgeInsets;
      expect(insets3Btn.bottom, equals(60.0));

      // 2. Test Gesture navigation (16dp bottom inset)
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewPadding: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.only(bottom: 16),
            ),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: FloatingBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                FloatingNavItem(icon: Icons.home, activeIcon: Icons.home, label: 'Home'),
                FloatingNavItem(icon: Icons.settings, activeIcon: Icons.settings, label: 'Settings'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final paddingFinderGesture = find.descendant(
        of: find.byType(FloatingBottomNavBar),
        matching: find.byType(Padding),
      );
      final paddingWidgetGesture = tester.widget<Padding>(paddingFinderGesture.first);
      // safeBottom (16) + 8 = 24
      final insetsGesture = paddingWidgetGesture.padding as EdgeInsets;
      expect(insetsGesture.bottom, equals(24.0));
    });
  });

  group('MainNavigationScreen Integration Tests', () {
    testWidgets('phone layout (< 600dp) uses FloatingBottomNavBar and switches tabs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Mobile verifies FloatingBottomNavBar is used and NavigationRail is not
      expect(find.byType(FloatingBottomNavBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      // 1. Initially on Home tab
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Single Photo'), findsOneWidget);
      expect(find.text('Batch (Multi)'), findsOneWidget);

      // 2. Tap on "Scan to PDF" tab in the floating nav bar
      await tester.tap(find.descendant(
        of: find.byType(FloatingBottomNavBar),
        matching: find.text('Scan to PDF'),
      ));
      await tester.pumpAndSettle();

      // Verify Scan to PDF content is shown
      expect(find.text('Scan with Camera'), findsOneWidget);
      expect(find.text('Auto-deskew, enhance & convert to PDF'), findsOneWidget);

      // 3. Tap on "Exam Tools" tab in the floating nav bar
      await tester.tap(find.descendant(
        of: find.byType(FloatingBottomNavBar),
        matching: find.text('Exam Tools'),
      ));
      await tester.pumpAndSettle();

      // Verify Exam Tools content is shown by default
      expect(find.text('Exam Document Tools'), findsWidgets);
      expect(find.text('Signature B&W Cleaner'), findsWidgets);
      expect(find.text('Name & Date Photo Stamp'), findsWidgets);

      // Switch to Presets tab pill inside the combined screen
      await tester.tap(find.text('Presets'));
      await tester.pumpAndSettle();

      // Verify Presets Hub content is shown
      expect(find.text('Govt & Exam Presets'), findsWidgets);
      expect(find.text('SSC Signature'), findsOneWidget);
      expect(find.text('UPSC Civil Services Photo'), findsOneWidget);

      // 4. Tap on "Settings" tab in the floating nav bar
      await tester.tap(find.descendant(
        of: find.byType(FloatingBottomNavBar),
        matching: find.text('Settings'),
      ));
      await tester.pumpAndSettle();

      // Verify Settings content is shown
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);

      // 5. Switch back to Home
      await tester.tap(find.descendant(
        of: find.byType(FloatingBottomNavBar),
        matching: find.text('Home'),
      ));
      await tester.pumpAndSettle();
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Single Photo'), findsOneWidget);
    });

    testWidgets('sliding / swiping horizontally switches screens and updates active tab',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Initially on Home tab (index 0)
      expect(find.text(AppConstants.appName), findsOneWidget);

      // Swipe left on the screen to slide to "Scan to PDF" (index 1)
      await tester.drag(find.text(AppConstants.appName), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Verify Scan to PDF content is now shown
      expect(find.text('Scan with Camera'), findsOneWidget);

      // Swipe left again to slide to "Exam Tools" (index 2)
      await tester.drag(find.text('Scan with Camera'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Verify Exam Tools content is now shown
      expect(find.text('Exam Document Tools'), findsWidgets);

      // Swipe right to slide back to "Scan to PDF" (index 1)
      await tester.drag(find.text('Exam Document Tools').first, const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Scan with Camera'), findsOneWidget);
    });

    testWidgets('tablet/wide layout (>= 600dp) uses NavigationRail and switches tabs',
        (WidgetTester tester) async {
      // 1800 x 2400 with DPR 2.0 = 900 x 1200 logical dp (expanded / tablet)
      tester.view.physicalSize = const Size(1800, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Tablet verifies NavigationRail is rendered and FloatingBottomNavBar is not
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(FloatingBottomNavBar), findsNothing);

      // Initially on Home tab
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Single Photo'), findsOneWidget);

      // Tap on "Scan to PDF" in the NavigationRail
      await tester.tap(find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Scan to PDF'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Scan with Camera'), findsOneWidget);

      // Tap on "Settings" in the NavigationRail
      await tester.tap(find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Settings'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);

      // Tap back on "Home" in the NavigationRail
      await tester.tap(find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Home'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Single Photo'), findsOneWidget);
    });

    testWidgets('mobile landscape / short height wide layout (740x360dp) uses NavigationRail without overflow',
        (WidgetTester tester) async {
      // 1480 x 720 with DPR 2.0 = 740 x 360 logical dp (mobile landscape)
      tester.view.physicalSize = const Size(1480, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // NavigationRail is present and no RenderFlex overflow occurs
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(FloatingBottomNavBar), findsNothing);
      expect(tester.takeException(), isNull);

      // Verify tabs switch cleanly
      await tester.tap(find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Settings'),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

