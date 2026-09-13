import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/studio/widgets/crop_mode_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({Function(String?)? onResult}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await CropModeSheet.show(context);
                onResult?.call(result);
              },
              child: const Text('Open Crop Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  group('CropModeSheet Tests', () {
    testWidgets('Renders header, close icon, and both minimal option cards', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Crop Sheet'));
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Cropping Mode'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Cards
      expect(find.text('Standard Crop'), findsOneWidget);
      expect(find.text('Frame & Presets'), findsOneWidget);

      expect(find.text('Perspective Crop'), findsOneWidget);
      expect(find.text('4-Corner Deskew'), findsOneWidget);
    });

    testWidgets('Tapping Standard Crop pops with standard choice', (
      tester,
    ) async {
      String? returnedChoice;

      await tester.pumpWidget(
        buildTestWidget(onResult: (res) => returnedChoice = res),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Crop Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Standard Crop'));
      await tester.pumpAndSettle();

      expect(returnedChoice, equals('standard'));
    });

    testWidgets('Tapping Perspective Crop pops with perspective choice', (
      tester,
    ) async {
      String? returnedChoice;

      await tester.pumpWidget(
        buildTestWidget(onResult: (res) => returnedChoice = res),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Crop Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perspective Crop'));
      await tester.pumpAndSettle();

      expect(returnedChoice, equals('perspective'));
    });

    testWidgets('Tapping close button dismisses sheet without selection', (
      tester,
    ) async {
      String? returnedChoice;

      await tester.pumpWidget(
        buildTestWidget(onResult: (res) => returnedChoice = res),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Crop Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(returnedChoice, isNull);
    });
  });
}
