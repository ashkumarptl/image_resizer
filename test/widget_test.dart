import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/core/constants/app_constants.dart';
import 'package:image_resizer/main.dart';

void main() {
  testWidgets('App smoke test - verifies App Name rendered', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ImageToolsApp(),
      ),
    );

    expect(find.text(AppConstants.appName), findsOneWidget);
  });
}
