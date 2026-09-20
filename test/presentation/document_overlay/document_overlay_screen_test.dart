import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/presentation/document_overlay/document_overlay_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File dummyImage;

  setUp(() {
    final image = img.Image(width: 100, height: 100);
    img.fill(image, color: img.ColorRgba8(200, 50, 50, 255));
    final bytes = img.encodeJpg(image);
    dummyImage = File('${Directory.systemTemp.path}/test_overlay_doc.jpg');
    dummyImage.writeAsBytesSync(bytes);
  });

  tearDown(() {
    if (dummyImage.existsSync()) {
      dummyImage.deleteSync();
    }
  });

  testWidgets(
    'DocumentOverlayScreen renders studio UI, converts base document to layer on A4, and deletes it cleanly without resurrecting',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: DocumentOverlayScreen(initialImage: dummyImage)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check that the screen rendered with studio app bar title
      expect(find.text('Add Photo Studio'), findsOneWidget);

      // Verify that the preset chips exist
      expect(find.text('A4 Portrait'), findsOneWidget);

      // Tap 'A4 Portrait' format preset
      await tester.tap(find.text('A4 Portrait'));
      await tester.pumpAndSettle();

      // In A4 Portrait, the base document is automatically activated as a layer
      // Verify editing inspector appears
      expect(find.text('EDITING: PHOTO'), findsOneWidget);

      // Scroll inspector to make Delete button fully visible and tap it
      await tester.ensureVisible(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // After deletion, the photo inspector should no longer be editing
      expect(find.text('EDITING: PHOTO'), findsNothing);

      // Most importantly: the base document must NOT be rendered on canvas
      expect(find.byType(Image), findsNothing);

      // Undo button should be enabled in the top AppBar
      final undoFinder = find.byTooltip('Undo');
      expect(undoFinder, findsOneWidget);

      // Tap Undo to restore the deleted photo
      await tester.tap(undoFinder);
      await tester.pumpAndSettle();

      // The layer should be restored and Image should reappear
      expect(find.byType(Image), findsOneWidget);

      // Tap Redo to re-delete
      final redoFinder = find.byTooltip('Redo');
      expect(redoFinder, findsOneWidget);
      await tester.tap(redoFinder);
      await tester.pumpAndSettle();

      // Image is deleted again
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets(
    'Tapping base document in matchDocument mode selects it as a layer, and deleting removes it cleanly from canvas',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: DocumentOverlayScreen(initialImage: dummyImage)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Image starts rendered as base document
      expect(find.byType(Image), findsOneWidget);

      // Tap on the image to activate and select it as a layer
      await tester.tap(find.byType(Image));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Inspector appears
      expect(find.text('EDITING: PHOTO'), findsOneWidget);

      // Delete it via inspector
      await tester.ensureVisible(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Photo should now be completely deleted from canvas
      expect(find.byType(Image), findsNothing);

      // Reset button in AppBar should be enabled
      final resetFinder = find.byTooltip('Reset Document');
      expect(resetFinder, findsOneWidget);
      await tester.tap(resetFinder);
      await tester.pumpAndSettle();

      // Image is restored by Reset
      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping SIGNATURE tool opens bottom sheet with ListTiles without throwing ListTile assertion',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: DocumentOverlayScreen(initialImage: dummyImage)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap SIGNATURE in bottom dock
      final sigToolFinder = find.text('SIGNATURE');
      expect(sigToolFinder, findsOneWidget);
      await tester.tap(sigToolFinder);
      await tester.pumpAndSettle();

      // Verify bottom sheet appears with ListTiles
      expect(find.text('Add Digital Signature'), findsOneWidget);
      expect(find.text('Draw Signature Now'), findsOneWidget);
      expect(find.text('Import Signature Image'), findsOneWidget);

      // Dismiss sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Add Digital Signature'), findsNothing);
    },
  );
}
