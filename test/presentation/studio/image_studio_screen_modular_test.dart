import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/data/models/scan_project.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/presentation/scan_to_pdf/scan_project_detail_screen.dart';
import 'package:image_resizer/presentation/studio/image_studio_screen.dart';
import 'package:image_resizer/services/auth_service.dart';

class MockAuthService extends AuthService {
  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);

  @override
  User? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File dummyImage;

  setUpAll(() async {
    final image = img.Image(width: 100, height: 100);
    img.fill(image, color: img.ColorRgb8(100, 100, 100));
    final bytes = img.encodeJpg(image);

    dummyImage = File(
      '${Directory.systemTemp.path}/test_modular_studio_img.jpg',
    );
    await dummyImage.writeAsBytes(bytes);
  });

  tearDownAll(() async {
    if (dummyImage.existsSync()) {
      await dummyImage.delete();
    }
  });

  group('ImageStudioScreen Modular Tests', () {
    testWidgets('allowRePick: true shows Change Image button in AppBar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ImageStudioScreen(initialImage: dummyImage, allowRePick: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byTooltip('Change Image'), findsOneWidget);
    });

    testWidgets('allowRePick: false hides Change Image button in AppBar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ImageStudioScreen(
            initialImage: dummyImage,
            allowRePick: false,
            returnResultDirectly: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byTooltip('Change Image'), findsNothing);
    });

    testWidgets(
      'ScanProjectDetailScreen displays Studio action button on each page',
      (tester) async {
        final project = ScanProject(
          id: 'test_project_studio',
          name: 'Studio Test Docs',
          pagePaths: [dummyImage.path],
          pdfPath: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(MockAuthService()),
            ],
            child: MaterialApp(
              home: ScanProjectDetailScreen(initialProject: project),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tapping page opens preview with 'Studio Edit' option
        await tester.tap(find.text('1/1'));
        await tester.pumpAndSettle();
        expect(find.text('Studio Edit'), findsOneWidget);

        // Return to detail screen
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        // Switch to Grid View
        await tester.tap(find.byIcon(Icons.grid_view_rounded));
        await tester.pumpAndSettle();

        // Verify Grid item opens preview with Studio Edit
        expect(find.text('01'), findsOneWidget);
        await tester.ensureVisible(find.text('01'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('01'));
        await tester.pumpAndSettle();
        expect(find.text('Studio Edit'), findsOneWidget);
      },
    );

    testWidgets(
      'Tablet Landscape renders dual-pane layout with pinned save button and no bottom bar',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: ImageStudioScreen(
              initialImage: dummyImage,
              allowRePick: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // 1. Bottom toolbar is NOT present in tablet mode
        expect(find.text('Doc Filter'), findsNothing);

        // 2. Tablet tool selector tabs are present
        expect(find.text('Compress'), findsOneWidget);
        expect(find.text('Resize'), findsOneWidget);
        expect(find.text('Format'), findsOneWidget);
        expect(find.text('Tools'), findsOneWidget);

        // 3. Pinned Process & Save Image button is visible in inspector footer
        expect(find.text('Process & Save Image'), findsOneWidget);

        // 4. Switch to Tools tab and verify tools inspector appears
        await tester.tap(find.text('Tools'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('AI Background Remover'), findsOneWidget);
        expect(find.text('Perspective & Document Crop'), findsOneWidget);
        expect(find.text('Document Scanner Filter'), findsOneWidget);
        expect(find.text('Flip H'), findsOneWidget);
        expect(find.text('Flip V'), findsOneWidget);
      },
    );

    testWidgets(
      'Tablet Portrait renders preview canvas and inspector deck with pinned save button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1280);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: ImageStudioScreen(
              initialImage: dummyImage,
              allowRePick: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // 1. Bottom toolbar is NOT present in tablet mode
        expect(find.text('Doc Filter'), findsNothing);

        // 2. Tablet tool selector tabs are present in portrait deck
        expect(find.text('Compress'), findsOneWidget);
        expect(find.text('Resize'), findsOneWidget);
        expect(find.text('Format'), findsOneWidget);
        expect(find.text('Tools'), findsOneWidget);

        // 3. Pinned Process & Save Image button is visible
        expect(find.text('Process & Save Image'), findsOneWidget);

        // 4. Switch to Resize tab and verify resize controls
        await tester.tap(find.text('Resize'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Original'), findsOneWidget);
        expect(find.text('Exact (W×H)'), findsOneWidget);
        expect(find.text('Scale %'), findsOneWidget);
      },
    );
  });
}
