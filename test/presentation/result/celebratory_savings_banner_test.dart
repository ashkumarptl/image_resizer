import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/models/process_result.dart';
import 'package:image_resizer/presentation/result/widgets/celebratory_savings_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CelebratorySavingsBanner displays reduction percentage and size transition',
      (WidgetTester tester) async {
    const result = ProcessResult(
      originalPath: '/tmp/original.jpg',
      outputPath: '/tmp/optimized.jpg',
      originalSizeBytes: 3200 * 1024, // 3.125 MB
      outputSizeBytes: 48 * 1024,    // 48 KB (~98.5% reduced)
      originalWidth: 3000,
      originalHeight: 4000,
      outputWidth: 350,
      outputHeight: 450,
      outputFormat: 'jpg',
      finalQuality: 85,
      processingTime: Duration(milliseconds: 250),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CelebratorySavingsBanner(result: result),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify celebratory header
    expect(find.text('🎉'), findsOneWidget);
    expect(find.textContaining('Reduced by 99%'), findsOneWidget);
    expect(find.textContaining('➔'), findsOneWidget);

    // Verify progress bar and size labels
    expect(find.textContaining('Optimized: 48 KB'), findsOneWidget);
    expect(find.textContaining('Original: 3.1 MB'), findsOneWidget);
  });

  testWidgets('CelebratorySavingsBanner shows informational note when size not reduced',
      (WidgetTester tester) async {
    const result = ProcessResult(
      originalPath: '/tmp/original.png',
      outputPath: '/tmp/output.png',
      originalSizeBytes: 50 * 1024,
      outputSizeBytes: 55 * 1024,
      originalWidth: 300,
      originalHeight: 300,
      outputWidth: 300,
      outputHeight: 300,
      outputFormat: 'png',
      finalQuality: 100,
      processingTime: Duration(milliseconds: 120),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CelebratorySavingsBanner(result: result),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No celebration emoji when size was not reduced
    expect(find.text('🎉'), findsNothing);
    expect(find.textContaining('Dimensions matched exact portal specs'), findsOneWidget);
  });
}
