import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/core/layout/adaptive_layout.dart';

void main() {
  group('AdaptiveLayoutExtension Tests', () {
    testWidgets('calculates WindowSizeClass.compact for widths < 600', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late WindowSizeClass sizeClass;
      late bool isCompact;
      late bool isMediumOrWider;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              sizeClass = context.windowSizeClass;
              isCompact = context.isCompact;
              isMediumOrWider = context.isMediumOrWider;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(sizeClass, WindowSizeClass.compact);
      expect(isCompact, isTrue);
      expect(isMediumOrWider, isFalse);
    });

    testWidgets('calculates WindowSizeClass.medium for 600 <= width < 840', (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late WindowSizeClass sizeClass;
      late bool isMedium;
      late bool isMediumOrWider;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              sizeClass = context.windowSizeClass;
              isMedium = context.isMedium;
              isMediumOrWider = context.isMediumOrWider;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(sizeClass, WindowSizeClass.medium);
      expect(isMedium, isTrue);
      expect(isMediumOrWider, isTrue);
    });

    testWidgets('calculates WindowSizeClass.expanded for 840 <= width < 1200', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late WindowSizeClass sizeClass;
      late bool isExpanded;
      late bool isExpandedOrWider;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              sizeClass = context.windowSizeClass;
              isExpanded = context.isExpanded;
              isExpandedOrWider = context.isExpandedOrWider;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(sizeClass, WindowSizeClass.expanded);
      expect(isExpanded, isTrue);
      expect(isExpandedOrWider, isTrue);
    });

    testWidgets('responsiveValue selects correct value based on size class', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? value;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              value = context.responsiveValue(
                compact: 'compact_val',
                medium: 'medium_val',
                expanded: 'expanded_val',
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(value, 'compact_val');
    });
  });

  group('AdaptiveSupportingPane Tests', () {
    testWidgets('renders single column scrollable on compact screens', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveSupportingPane(
              primaryPane: Text('PRIMARY_PANE'),
              supportingPane: Text('SUPPORTING_PANE'),
              bottomAction: Text('BOTTOM_ACTION'),
            ),
          ),
        ),
      );

      expect(find.text('PRIMARY_PANE'), findsOneWidget);
      expect(find.text('SUPPORTING_PANE'), findsOneWidget);
      expect(find.text('BOTTOM_ACTION'), findsOneWidget);
      // In compact mode, panes are arranged vertically inside a SingleChildScrollView
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('renders side-by-side Row on medium or wider screens', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveSupportingPane(
              primaryPane: Text('PRIMARY_PANE'),
              supportingPane: Text('SUPPORTING_PANE'),
              bottomAction: Text('BOTTOM_ACTION'),
            ),
          ),
        ),
      );

      expect(find.text('PRIMARY_PANE'), findsOneWidget);
      expect(find.text('SUPPORTING_PANE'), findsOneWidget);
      expect(find.text('BOTTOM_ACTION'), findsOneWidget);

      // In wide mode, panes are wrapped in a Row with 2 Expanded children
      final rowFinder = find.byType(Row);
      expect(rowFinder, findsWidgets);
    });
  });

  group('AdaptivePageContainer Tests', () {
    testWidgets('constrains child within maxWidth', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptivePageContainer(
              maxWidth: 1000,
              child: Text('CENTERED_CONTENT'),
            ),
          ),
        ),
      );

      expect(find.text('CENTERED_CONTENT'), findsOneWidget);
      final constrainedBox = tester.widget<ConstrainedBox>(
        find.ancestor(
          of: find.text('CENTERED_CONTENT'),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(constrainedBox.constraints.maxWidth, 1000);
    });
  });
}
