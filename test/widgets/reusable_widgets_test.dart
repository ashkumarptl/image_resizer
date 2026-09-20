import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/presentation/widgets/app_bottom_sheet.dart';
import 'package:image_resizer/presentation/widgets/format_selector.dart';
import 'package:image_resizer/presentation/widgets/hold_to_compare_button.dart';
import 'package:image_resizer/presentation/widgets/scale_percentage_selector.dart';
import 'package:image_resizer/presentation/widgets/target_size_selector.dart';
import 'package:image_resizer/services/image_service/target_size_compressor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithMaterial(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('TargetSizeSelector Tests', () {
    testWidgets('renders default preset chips and responds to selection', (
      tester,
    ) async {
      int? selectedSize;
      final controller = TextEditingController(text: '100');

      await tester.pumpWidget(
        wrapWithMaterial(
          TargetSizeSelector(
            selectedSizeKB: 100,
            onSizeChanged: (val) => selectedSize = val,
            customSizeController: controller,
          ),
        ),
      );

      expect(find.text('50 KB'), findsOneWidget);
      expect(find.text('100 KB'), findsOneWidget);
      expect(find.text('200 KB'), findsOneWidget);

      await tester.tap(find.text('50 KB'));
      await tester.pumpAndSettle();

      expect(selectedSize, 50);
      expect(controller.text, '50');
    });

    testWidgets('entering valid custom KB triggers onSizeChanged', (
      tester,
    ) async {
      int? selectedSize;
      final controller = TextEditingController(text: '100');

      await tester.pumpWidget(
        wrapWithMaterial(
          TargetSizeSelector(
            selectedSizeKB: 100,
            onSizeChanged: (val) => selectedSize = val,
            customSizeController: controller,
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, '175');
      await tester.pumpAndSettle();

      expect(selectedSize, 175);
    });
  });

  group('FormatSelector Tests', () {
    testWidgets('renders JPG, WEBP, PNG and responds to taps', (tester) async {
      String? chosenFormat;

      await tester.pumpWidget(
        wrapWithMaterial(
          FormatSelector(
            selectedFormat: 'jpg',
            onFormatChanged: (val) => chosenFormat = val,
            isSegmented: true,
          ),
        ),
      );

      expect(find.text('JPG'), findsOneWidget);
      expect(find.text('WEBP'), findsOneWidget);
      expect(find.text('PNG'), findsOneWidget);

      await tester.tap(find.text('WEBP'));
      await tester.pumpAndSettle();

      expect(chosenFormat, 'webp');
    });
  });

  group('ScalePercentageSelector Tests', () {
    testWidgets('renders default percentages and fires callback on tap', (
      tester,
    ) async {
      int? chosenScale;

      await tester.pumpWidget(
        wrapWithMaterial(
          ScalePercentageSelector(
            selectedScalePercentage: 100,
            onScalePercentageChanged: (val) => chosenScale = val,
          ),
        ),
      );

      expect(find.text('100%'), findsNWidgets(2)); // header + chip
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);

      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();

      expect(chosenScale, 50);
    });
  });

  group('AppBottomSheet Tests', () {
    testWidgets('renders BottomSheetDragHandle and AppBottomSheetHeader', (
      tester,
    ) async {
      bool closed = false;

      await tester.pumpWidget(
        wrapWithMaterial(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BottomSheetDragHandle(),
              AppBottomSheetHeader(
                title: 'Test Sheet Title',
                subtitle: 'Test subtitle',
                icon: Icons.settings,
                onClose: () => closed = true,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(BottomSheetDragHandle), findsOneWidget);
      expect(find.text('Test Sheet Title'), findsOneWidget);
      expect(find.text('Test subtitle'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });
  });

  group('HoldToCompareButton Tests', () {
    testWidgets('toggles comparison state on pointer down and up', (
      tester,
    ) async {
      bool isComparing = false;

      await tester.pumpWidget(
        wrapWithMaterial(
          StatefulBuilder(
            builder: (context, setState) {
              return HoldToCompareButton(
                isComparing: isComparing,
                onComparisonChanged: (val) {
                  setState(() => isComparing = val);
                },
              );
            },
          ),
        ),
      );

      expect(find.text('Hold to Compare'), findsOneWidget);

      final gesture = await tester.createGesture();
      await gesture.down(tester.getCenter(find.byType(HoldToCompareButton)));
      await tester.pump();

      expect(isComparing, isTrue);
      expect(find.text('Showing Original'), findsOneWidget);

      await gesture.up();
      await tester.pump();

      expect(isComparing, isFalse);
      expect(find.text('Hold to Compare'), findsOneWidget);
    });
  });

  group('TargetSizeCompressor Tests', () {
    test('compresses image strictly under target size', () {
      final sample = img.Image(width: 300, height: 300);
      img.fill(sample, color: img.ColorRgb8(200, 100, 50));

      final result = TargetSizeCompressor.compressToTargetSize(
        sample,
        targetMaxBytes: 20 * 1024,
      );

      expect(result.bytes.length, lessThanOrEqualTo(20 * 1024));
      expect(result.quality, greaterThanOrEqualTo(15));
      expect(result.image.width, greaterThan(0));
    });
  });
}
