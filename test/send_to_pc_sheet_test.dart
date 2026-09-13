import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/models/process_result.dart';
import 'package:image_resizer/presentation/result/result_screen.dart';
import 'package:image_resizer/presentation/widgets/send_to_pc_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sampleFile;

  setUp(() async {
    HttpOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/network_info'),
          (call) async {
            if (call.method == 'wifiIPAddress') {
              return '192.168.1.15';
            }
            return null;
          },
        );
    tempDir = await Directory.systemTemp.createTemp('sheet_test_');
    sampleFile = File('${tempDir.path}/test_img.jpg');
    await sampleFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'SendToPcSheet renders header, clean QR code, Copy IP button, and 3-step visual graphics',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SendToPcSheet(filePaths: [sampleFile.path])),
        ),
      );

      // Initial pump
      await tester.pump();
      expect(find.text('Send to PC / Browser'), findsOneWidget);
      expect(
        find.textContaining('Cyber Cafe & Form Fillers Transfer'),
        findsOneWidget,
      );

      // Wait for server to bind & update state using runAsync because HttpServer and NetworkInterface use real I/O
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      // Verify QR Code & Scan hint
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Scan with laptop webcam or camera'), findsOneWidget);

      // Verify Local IP URL & Copy IP Button
      expect(find.textContaining('http://'), findsOneWidget);
      expect(find.text('Copy IP'), findsOneWidget);

      // Test clicking "Copy IP" button
      await tester.tap(find.text('Copy IP'));
      await tester.pump();
      expect(find.text('Copied!'), findsOneWidget);

      // Verify 3-step visual graphics
      expect(find.text('HOW TO TRANSFER IN 3 EASY STEPS'), findsOneWidget);
      expect(find.text('STEP 1'), findsOneWidget);
      expect(find.text('Connect Same Network'), findsOneWidget);
      expect(
        find.textContaining('Connect laptop to the same Wi-Fi'),
        findsOneWidget,
      );

      expect(find.text('STEP 2'), findsOneWidget);
      expect(find.text('Open in PC Browser'), findsOneWidget);

      expect(find.text('STEP 3'), findsOneWidget);
      expect(find.text('Instant Download for Forms'), findsOneWidget);

      // Verify Done button
      expect(find.text('Done / Stop Sharing'), findsOneWidget);
    },
  );

  testWidgets(
    'ResultScreen renders prominent CYBER CAFE / PC badge on Send to PC button and helper hint',
    (tester) async {
      final mockResult = ProcessResult(
        originalPath: sampleFile.path,
        outputPath: sampleFile.path,
        originalSizeBytes: 1024 * 500,
        outputSizeBytes: 1024 * 100,
        originalWidth: 1000,
        originalHeight: 1000,
        outputWidth: 500,
        outputHeight: 500,
        outputFormat: 'jpg',
        finalQuality: 80,
        processingTime: const Duration(milliseconds: 150),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: ResultScreen(result: mockResult)),
        ),
      );

      await tester.pumpAndSettle();

      // Verify prominent CYBER CAFE / PC badge
      expect(find.text('CYBER CAFE / PC'), findsOneWidget);

      // Verify Send to PC button
      expect(find.widgetWithText(OutlinedButton, 'Send to PC'), findsOneWidget);

      // Verify helper hint card for form filling
      expect(
        find.textContaining(
          'Filling a form on PC? Transfer wirelessly without WhatsApp or cable.',
        ),
        findsOneWidget,
      );
    },
  );
}
