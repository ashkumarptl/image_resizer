import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/models/process_result.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/presentation/result/result_screen.dart';
import 'package:image_resizer/presentation/result/widgets/celebratory_savings_banner.dart';
import 'package:image_resizer/presentation/result/widgets/next_actions_section.dart';
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

  const channel = MethodChannel('com.ashspark.image_resizer/system_integration');
  final List<MethodCall> methodCalls = [];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    methodCalls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      methodCalls.add(call);
      switch (call.method) {
        case 'openInGallery':
          return true;
        case 'printImage':
          return true;
        default:
          return null;
      }
    });
  });

  testWidgets('ResultScreen displays celebratory banner, print button, and next action suggestions',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tempDir = Directory.systemTemp.createTempSync('result_feedback_test_');
    final origFile = File('${tempDir.path}/orig.jpg')..writeAsBytesSync([1, 2, 3]);
    final outFile = File('${tempDir.path}/out.jpg')..writeAsBytesSync([1]);

    final result = ProcessResult(
      originalPath: origFile.path,
      outputPath: outFile.path,
      originalSizeBytes: 3000 * 1024, // 2.9 MB
      outputSizeBytes: 48 * 1024,    // 48 KB (~98% reduced)
      originalWidth: 2400,
      originalHeight: 3000,
      outputWidth: 350,
      outputHeight: 450,
      outputFormat: 'jpg',
      finalQuality: 85,
      processingTime: const Duration(milliseconds: 200),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: MaterialApp(
          home: ResultScreen(result: result),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify CelebratorySavingsBanner is present and shows reduction
    expect(find.byType(CelebratorySavingsBanner), findsOneWidget);
    expect(find.text('🎉'), findsOneWidget);
    expect(find.textContaining('Reduced by 98%'), findsOneWidget);

    // 2. Verify Print buttons exist in AppBar and Actions Row
    expect(find.byIcon(Icons.print_outlined), findsWidgets);
    expect(find.text('Print'), findsOneWidget);

    // 3. Tap Print button
    await tester.tap(find.text('Print'));
    await tester.pumpAndSettle();

    expect(
      methodCalls.any((call) => call.method == 'printImage'),
      isTrue,
    );

    // 4. Verify NextActionsSection is rendered
    expect(find.byType(NextActionsSection), findsOneWidget);
    expect(find.text('NEXT ACTIONS FOR YOUR FORM'), findsOneWidget);
    expect(find.text('Need Signature for same form?'), findsOneWidget);

    tempDir.deleteSync(recursive: true);
  });
}
