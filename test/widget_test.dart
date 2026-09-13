import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/core/constants/app_constants.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/main.dart';
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

  testWidgets('First-time launch renders OnboardingScreen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: const ImageToolsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Photo & Image Studio'), findsOneWidget);
    expect(find.text('ALL-IN-ONE EDIT STUDIO'), findsOneWidget);
    expect(find.text('Smart Target Size Compressor'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('Returning user launch renders MainNavigationScreen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'pref_onboarding_completed': true,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: const ImageToolsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('Single Photo'), findsOneWidget);
    expect(find.text('Batch (Multi)'), findsOneWidget);
    expect(find.text('Quick Utilities'), findsOneWidget);
  });
}
