import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/models/process_result.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/data/repositories/history_repository.dart';
import 'package:image_resizer/presentation/result/result_screen.dart';
import 'package:image_resizer/services/auth_service.dart';
import 'package:image_resizer/services/system_integration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends AuthService {
  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);

  @override
  User? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'com.ashspark.image_resizer/system_integration',
  );
  const galChannel = MethodChannel('gal');
  final List<MethodCall> methodCalls = [];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    methodCalls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          methodCalls.add(call);
          switch (call.method) {
            case 'getInitialSharedFile':
              return '/path/to/shared/image.jpg';
            case 'getInitialShortcut':
              return 'quick_compress';
            case 'openInGallery':
              return true;
            default:
              return null;
          }
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(galChannel, (MethodCall call) async {
          switch (call.method) {
            case 'hasAccess':
              return true;
            case 'requestAccess':
              return true;
            case 'putImage':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(galChannel, null);
  });

  group('SystemIntegrationService Unit Tests', () {
    test(
      'getInitialSharedFile invokes channel and returns file path',
      () async {
        final service = SystemIntegrationService.instance;
        final path = await service.getInitialSharedFile();

        expect(path, equals('/path/to/shared/image.jpg'));
        expect(
          methodCalls.any((call) => call.method == 'getInitialSharedFile'),
          isTrue,
        );
      },
    );

    test(
      'getInitialShortcut invokes channel and returns shortcut id',
      () async {
        final service = SystemIntegrationService.instance;
        final shortcut = await service.getInitialShortcut();

        expect(shortcut, equals('quick_compress'));
        expect(
          methodCalls.any((call) => call.method == 'getInitialShortcut'),
          isTrue,
        );
      },
    );

    test('openInGallery invokes channel with correct path', () async {
      final service = SystemIntegrationService.instance;
      final success = await service.openInGallery(
        '/storage/emulated/0/DCIM/test.jpg',
      );

      expect(success, isTrue);
      final openCall = methodCalls.firstWhere(
        (call) => call.method == 'openInGallery',
      );
      expect(
        openCall.arguments,
        equals({'path': '/storage/emulated/0/DCIM/test.jpg'}),
      );
    });

    test('listens to incoming broadcast callbacks from native', () async {
      final service = SystemIntegrationService.instance;
      service.initialize();

      String? receivedPath;
      final sub = service.onSharedFile.listen((path) {
        receivedPath = path;
      });

      // Simulate native calling onSharedFileReceived
      final ByteData data = const StandardMethodCodec().encodeMethodCall(
        const MethodCall(
          'onSharedFileReceived',
          '/storage/emulated/0/DCIM/photo.jpg',
        ),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'com.ashspark.image_resizer/system_integration',
            data,
            (_) {},
          );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedPath, equals('/storage/emulated/0/DCIM/photo.jpg'));

      await sub.cancel();
    });

    test('listens to incoming shortcut broadcast from native', () async {
      final service = SystemIntegrationService.instance;
      service.initialize();

      String? receivedShortcut;
      final sub = service.onShortcut.listen((shortcut) {
        receivedShortcut = shortcut;
      });

      // Simulate native calling onShortcutReceived
      final ByteData data = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onShortcutReceived', 'photo_stamp'),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'com.ashspark.image_resizer/system_integration',
            data,
            (_) {},
          );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedShortcut, equals('photo_stamp'));

      await sub.cancel();
    });
  });

  group('ResultScreen - Open in Gallery Integration Tests', () {
    testWidgets(
      'displays Save to Gallery, saves successfully, and opens in Gallery via intent',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final tempDir = Directory.systemTemp.createTempSync('result_test_');
        final testFile = File('${tempDir.path}/test_output.jpg')
          ..writeAsBytesSync([1, 2, 3]);

        final dummyResult = ProcessResult(
          originalPath: testFile.path,
          outputPath: testFile.path,
          originalSizeBytes: 1024 * 500,
          outputSizeBytes: 1024 * 48,
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
            overrides: [
              authServiceProvider.overrideWithValue(MockAuthService()),
              historyRepositoryProvider.overrideWithValue(HistoryRepository()),
            ],
            child: MaterialApp(home: ResultScreen(result: dummyResult)),
          ),
        );

        await tester.pumpAndSettle();

        // Initially, "Save to Gallery" is visible
        expect(find.text('Save to Gallery'), findsOneWidget);
        expect(find.text('Open in Gallery'), findsNothing);

        // Tap "Save to Gallery"
        await tester.ensureVisible(find.text('Save to Gallery'));
        await tester.tap(find.text('Save to Gallery'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Should now show Saved status and Open in Gallery button
        expect(find.text('Saved ✓'), findsOneWidget);
        expect(find.text('Open in Gallery'), findsOneWidget);

        // Tap "Open in Gallery"
        await tester.tap(find.text('Open in Gallery'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          methodCalls.any((call) => call.method == 'openInGallery'),
          isTrue,
        );

        tempDir.deleteSync(recursive: true);
      },
    );
  });
}
