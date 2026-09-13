import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/widgets/image_source_picker_sheet.dart';

void main() {
  testWidgets(
    'ImageSourcePickerSheet exposes ML Kit single and batch methods',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Test Runner'))),
      );

      // Verify ImageSourcePickerSheet methods exist and are static entry points
      expect(ImageSourcePickerSheet.show, isNotNull);
      expect(ImageSourcePickerSheet.showMulti, isNotNull);
      expect(AppImageSource.values, contains(AppImageSource.smartScanner));
      expect(AppImageSource.values, contains(AppImageSource.gallery));
    },
  );

  testWidgets(
    'ImageSourcePickerSheet.show renders bottom sheet with ML Kit and Gallery options',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () => ImageSourcePickerSheet.show(ctx),
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Select Photo / Document'), findsOneWidget);
      expect(find.text('Smart Document Scanner'), findsOneWidget);
      expect(find.text('ML KIT'), findsOneWidget);
      expect(find.text('Import from Gallery'), findsOneWidget);
    },
  );

  testWidgets(
    'ImageSourcePickerSheet.showMulti renders batch bottom sheet with ML Kit and Gallery options',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () => ImageSourcePickerSheet.showMulti(ctx),
                  child: const Text('Open Multi Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Multi Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Select Images Source'), findsOneWidget);
      expect(find.text('Batch Document Scanner'), findsOneWidget);
      expect(find.text('ML KIT'), findsOneWidget);
      expect(find.text('Import from Gallery'), findsOneWidget);
    },
  );
}
