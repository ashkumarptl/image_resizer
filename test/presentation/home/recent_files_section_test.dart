import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/models/history_item.dart';
import 'package:image_resizer/presentation/home/widgets/recent_files_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<HistoryItem> mockHistoryItems = [
    HistoryItem(
      id: '1',
      filePath: '/dummy/path/image1.png',
      originalPath: '/dummy/path/orig1.png',
      thumbnailPath: '',
      processedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      originalSizeBytes: 1363148, // 1.3 MB
      outputSizeBytes: 391577,    // 382.4 KB
      format: 'PNG',
      width: 683,
      height: 384,
    ),
    HistoryItem(
      id: '2',
      filePath: '/dummy/path/image2.jpg',
      originalPath: '/dummy/path/orig2.jpg',
      thumbnailPath: '',
      processedAt: DateTime.now().subtract(const Duration(hours: 1)),
      originalSizeBytes: 5242880,
      outputSizeBytes: 1048576,
      format: 'JPG',
      width: 1920,
      height: 1080,
    ),
  ];

  group('RecentFilesSection Responsive & Overflow Tests', () {
    testWidgets('renders without overflow on narrow width constrained container (98.6px available for text)',
        (WidgetTester tester) async {
      // Simulate narrow container width where each cell has tight width ~238px
      tester.view.physicalSize = const Size(640, 960);
      tester.view.devicePixelRatio = 2.0; // 320 x 480 dp
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 250, // very tight width
                child: RecentFilesSection(
                  historyItems: mockHistoryItems,
                  onItemTap: (_) {},
                  onClearHistory: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Recent Files'), findsOneWidget);
      expect(find.text('683x384 · PNG'), findsOneWidget);
    });

    testWidgets('renders without overflow on short mobile landscape screen',
        (WidgetTester tester) async {
      // Mobile landscape screen: 740 x 360 logical dp
      tester.view.physicalSize = const Size(1480, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecentFilesSection(
                historyItems: mockHistoryItems,
                onItemTap: (_) {},
                onClearHistory: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Recent Files'), findsOneWidget);
    });
  });
}
