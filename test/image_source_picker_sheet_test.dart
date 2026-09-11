import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/widgets/image_source_picker_sheet.dart';

void main() {
  testWidgets('ImageSourcePickerSheet exposes ML Kit single and batch methods',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Test Runner'),
        ),
      ),
    );

    // Verify ImageSourcePickerSheet methods exist and are static entry points
    expect(ImageSourcePickerSheet.show, isNotNull);
    expect(ImageSourcePickerSheet.showMulti, isNotNull);
    expect(AppImageSource.values, contains(AppImageSource.smartScanner));
  });
}
