import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/studio/widgets/format_options_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    String initialFormat = 'jpg',
    double initialQuality = 85.0,
    int? initialDpi,
    Function(String, double, int?)? onApply,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                FormatOptionsSheet.show(
                  context,
                  initialFormat: initialFormat,
                  initialQuality: initialQuality,
                  initialDpi: initialDpi,
                  onApply: (format, quality, dpi) {
                    onApply?.call(format, quality, dpi);
                  },
                );
              },
              child: const Text('Open Format Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  group('FormatOptionsSheet Tests', () {
    testWidgets('Renders minimal header, 3 format tabs, and Apply button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Format Sheet'));
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Output Format & Quality'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // 3 format tabs
      expect(find.text('JPG / JPEG'), findsOneWidget);
      expect(find.text('WebP'), findsOneWidget);
      expect(find.text('PNG'), findsOneWidget);

      // Quality Slider for JPG
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);

      // DPI Chips
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('72 (Web)'), findsOneWidget);
      expect(find.text('300 (UPSC) ★'), findsOneWidget);

      // Apply button
      expect(find.text('Apply Format'), findsOneWidget);
    });

    testWidgets('Switching to PNG hides slider and shows lossless note', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Format Sheet'));
      await tester.pumpAndSettle();

      // Tap PNG tab
      await tester.tap(find.text('PNG'));
      await tester.pumpAndSettle();

      // Slider is hidden
      expect(find.byType(Slider), findsNothing);
      expect(
        find.textContaining('PNG preserves full lossless transparency'),
        findsOneWidget,
      );

      // Switch back to WebP
      await tester.tap(find.text('WebP'));
      await tester.pumpAndSettle();

      // Slider reappears
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets(
      'Selecting DPI and tapping Apply Format calls onApply with correct values',
      (tester) async {
        String? appliedFormat;
        double? appliedQuality;
        int? appliedDpi;

        await tester.pumpWidget(
          buildTestWidget(
            onApply: (f, q, d) {
              appliedFormat = f;
              appliedQuality = q;
              appliedDpi = d;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Format Sheet'));
        await tester.pumpAndSettle();

        // Select WebP
        await tester.tap(find.text('WebP'));
        await tester.pumpAndSettle();

        // Select 300 DPI
        await tester.tap(find.text('300 (UPSC) ★'));
        await tester.pumpAndSettle();

        // Tap Apply
        await tester.tap(find.text('Apply Format'));
        await tester.pumpAndSettle();

        expect(appliedFormat, equals('webp'));
        expect(appliedQuality, equals(85.0));
        expect(appliedDpi, equals(300));
      },
    );
  });
}
