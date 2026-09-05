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

  testWidgets('App smoke test - verifies App Name rendered', (WidgetTester tester) async {
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
    expect(find.text('Single Studio'), findsOneWidget);
    expect(find.text('Batch Optimizer'), findsOneWidget);
    expect(find.text('Core Studio'), findsOneWidget);
  });
}
