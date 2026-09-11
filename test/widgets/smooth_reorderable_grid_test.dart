import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/widgets/smooth_reorderable_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SmoothReorderableGrid renders items and handles tap', (tester) async {
    int? tappedIndex;
    final items = ['Item 1', 'Item 2', 'Item 3', 'Item 4'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmoothReorderableGrid(
            itemCount: items.length,
            crossAxisCount: 2,
            itemBuilder: (context, index, isDragging) {
              return Container(
                color: Colors.blue,
                child: Center(child: Text(items[index])),
              );
            },
            onTapItem: (index) {
              tappedIndex = index;
            },
            onReorder: (oldIdx, newIdx) {},
          ),
        ),
      ),
    );

    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
    expect(find.text('Item 3'), findsOneWidget);
    expect(find.text('Item 4'), findsOneWidget);

    // Tap Item 2
    await tester.tap(find.text('Item 2'));
    await tester.pump();
    expect(tappedIndex, 1);
  });

  testWidgets('SmoothReorderableGrid long-press lifts item and creates placeholder gap', (tester) async {
    final items = ['Page 1', 'Page 2', 'Page 3', 'Page 4'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmoothReorderableGrid(
            itemCount: items.length,
            crossAxisCount: 2,
            itemBuilder: (context, index, isDragging) {
              return Container(
                key: ValueKey('card_$index'),
                color: isDragging ? Colors.teal : Colors.blue,
                child: Center(child: Text(items[index])),
              );
            },
            onReorder: (oldIdx, newIdx) {},
          ),
        ),
      ),
    );

    // Start long press on Page 1
    final gesture = await tester.startGesture(tester.getCenter(find.text('Page 1')));
    await tester.pump(const Duration(milliseconds: 600)); // Trigger long press

    // Placeholder gap should now be present
    expect(find.byKey(const ValueKey('grid_placeholder_gap')), findsOneWidget);

    // Cancel drag gesture
    await gesture.cancel();
    await tester.pumpAndSettle();

    // After cancel, placeholder should be removed
    expect(find.byKey(const ValueKey('grid_placeholder_gap')), findsNothing);
  });

  testWidgets('SmoothReorderableGrid drag-and-drop fires onReorder callback with correct indices',
      (tester) async {
    int? reorderOld;
    int? reorderNew;
    final items = ['Alpha', 'Beta', 'Gamma', 'Delta'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmoothReorderableGrid(
            itemCount: items.length,
            crossAxisCount: 2,
            itemBuilder: (context, index, isDragging) {
              return Container(
                color: isDragging ? Colors.cyan : Colors.grey,
                child: Center(child: Text(items[index])),
              );
            },
            onReorder: (oldIdx, newIdx) {
              reorderOld = oldIdx;
              reorderNew = newIdx;
            },
          ),
        ),
      ),
    );

    // Long press Alpha (slot 0)
    final gesture = await tester.startGesture(tester.getCenter(find.text('Alpha')));
    await tester.pump(const Duration(milliseconds: 600));

    // Move over Beta (slot 1)
    final betaCenter = tester.getCenter(find.text('Beta'));
    await gesture.moveTo(betaCenter);
    await tester.pump(const Duration(milliseconds: 50));

    // Release gesture
    await gesture.up();
    await tester.pumpAndSettle();

    expect(reorderOld, 0);
    expect(reorderNew, 1);
  });

  testWidgets('SmoothReorderableGrid multi-select group drag creates multiple placeholder gaps and shows badge',
      (tester) async {
    final items = ['Page 1', 'Page 2', 'Page 3', 'Page 4'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmoothReorderableGrid(
            itemCount: items.length,
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            selectedIndexes: const {0, 1},
            itemBuilder: (context, index, isDragging) {
              return Container(
                key: ValueKey('card_$index'),
                color: isDragging ? Colors.teal : Colors.blue,
                child: Center(child: Text(items[index])),
              );
            },
            onReorder: (oldIdx, newIdx) {},
          ),
        ),
      ),
    );

    // Long press on Page 2 (index 1, which is part of selected {0, 1})
    final gesture = await tester.startGesture(tester.getCenter(find.text('Page 2')));
    await tester.pump(const Duration(milliseconds: 600));

    // Both placeholder gaps should now be present
    expect(find.byKey(const ValueKey('grid_placeholder_gap')), findsOneWidget);
    expect(find.byKey(const ValueKey('grid_placeholder_gap_1')), findsOneWidget);

    // Selected count badge '2' should be visible on the drag stack
    expect(find.text('2'), findsOneWidget);

    // Cancel drag gesture
    await gesture.cancel();
    await tester.pumpAndSettle();

    // After cancel, placeholders should be removed
    expect(find.byKey(const ValueKey('grid_placeholder_gap')), findsNothing);
    expect(find.byKey(const ValueKey('grid_placeholder_gap_1')), findsNothing);
  });

  testWidgets('SmoothReorderableGrid multi-select group drop fires onGroupReorder preserving internal order',
      (tester) async {
    List<int>? reportedNewOrder;
    final items = ['P0', 'P1', 'P2', 'P3'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmoothReorderableGrid(
            itemCount: items.length,
            crossAxisCount: 4,
            selectedIndexes: const {1, 3}, // P1 and P3 selected
            itemBuilder: (context, index, isDragging) {
              return Container(
                key: ValueKey('card_$index'),
                color: isDragging ? Colors.teal : Colors.blue,
                child: Center(child: Text(items[index])),
              );
            },
            onReorder: (oldIdx, newIdx) {},
            onGroupReorder: (newOrder) {
              reportedNewOrder = newOrder;
            },
          ),
        ),
      ),
    );

    // Long press P3 (selected index 3)
    final gesture = await tester.startGesture(tester.getCenter(find.text('P3')));
    await tester.pump(const Duration(milliseconds: 600));

    // Drag to slot 0 (P0)
    final p0Center = tester.getCenter(find.text('P0'));
    await gesture.moveTo(p0Center);
    await tester.pump(const Duration(milliseconds: 50));

    // Release gesture
    await gesture.up();
    await tester.pumpAndSettle();

    expect(reportedNewOrder, isNotNull);
    // Group {1, 3} was moved to the beginning, preserving internal order: [1, 3, 0, 2]
    expect(reportedNewOrder, [1, 3, 0, 2]);
  });
}

