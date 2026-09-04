import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('SendToPcSheet renders header, QR code and instructions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SendToPcSheet(filePaths: [sampleFile.path]),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    expect(find.text('Send to PC / Browser'), findsOneWidget);

    // Wait for server to bind & update state using runAsync because HttpServer and NetworkInterface use real I/O
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    // Verify UI components rendered
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('http://'), findsOneWidget);
    expect(find.textContaining('Connect laptop to the same Wi-Fi'), findsOneWidget);
    expect(find.text('Done / Stop Sharing'), findsOneWidget);
  });
}
