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

  group('Adaptive Font & Icon Scaling Tests', () {
    testWidgets('returns compact size on phone screen (<600dp)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late double fontSize;
      late double iconSize;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              fontSize = context.adaptiveFontSize(14);
              iconSize = context.adaptiveIconSize(24);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(fontSize, 14.0);
      expect(iconSize, 24.0);
    });

    testWidgets('scales up font and icon sizes on compact-medium tablet/foldable (600-719dp shortest side)', (tester) async {
      tester.view.physicalSize = const Size(640, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late double defaultScaledFont;
      late double explicitTabletFont;
      late double smallFontClamped;
      late double defaultScaledIcon;
      late double explicitTabletIcon;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              defaultScaledFont = context.adaptiveFontSize(16);
              explicitTabletFont = context.adaptiveFontSize(16, tabletSize: 20);
              smallFontClamped = context.adaptiveFontSize(9.5);
              defaultScaledIcon = context.adaptiveIconSize(24);
              explicitTabletIcon = context.adaptiveIconSize(24, tabletSize: 30);
              return const SizedBox();
            },
          ),
        ),
      );

      // Default scale is ~1.32x (16 * 1.32 = 21.12)
      expect(defaultScaledFont, closeTo(21.12, 0.01));
      expect(explicitTabletFont, 20.0);
      // Sub-12sp font gets clamped to minimum readable floor (14.0sp)
      expect(smallFontClamped, greaterThanOrEqualTo(14.0));

      // Icon default scale is ~1.36x (24 * 1.36 = 32.64)
      expect(defaultScaledIcon, closeTo(32.64, 0.01));
      expect(explicitTabletIcon, 30.0);
    });

    testWidgets('scales up font and icon sizes on large tablet (expanded or portrait tablet shortestSide >= 720dp)', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late double defaultScaledFont;
      late double explicitLargeFont;
      late double autoScaledTabletFont;
      late double defaultScaledIcon;
      late double explicitLargeIcon;
      late double autoScaledTabletIcon;
      late bool isLargeTablet;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isLargeTablet = context.isLargeTablet;
              defaultScaledFont = context.adaptiveFontSize(16);
              explicitLargeFont = context.adaptiveFontSize(16, largeTabletSize: 26);
              autoScaledTabletFont = context.adaptiveFontSize(16, tabletSize: 20);
              defaultScaledIcon = context.adaptiveIconSize(24);
              explicitLargeIcon = context.adaptiveIconSize(24, largeTabletSize: 40);
              autoScaledTabletIcon = context.adaptiveIconSize(24, tabletSize: 30);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isLargeTablet, isTrue);
      // Default scale on large tablet is ~1.55x (16 * 1.55 = 24.8)
      expect(defaultScaledFont, closeTo(24.8, 0.01));
      expect(explicitLargeFont, 26.0);
      // Auto-scaled tabletSize is (20 * 1.22).roundToDouble() = 24.0
      expect(autoScaledTabletFont, 24.0);

      // Default icon scale on large tablet is 1.55x (24 * 1.55 = 37.2)
      expect(defaultScaledIcon, closeTo(37.2, 0.01));
      expect(explicitLargeIcon, 40.0);
      // Auto-scaled tabletSize is (30 * 1.25).roundToDouble() = 38.0
      expect(autoScaledTabletIcon, 38.0);
    });

    testWidgets('identifies portrait tablet (e.g. 834x1194 or 768x1024) as isLargeTablet', (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late bool isLargeTablet;
      late bool isPortrait;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isLargeTablet = context.isLargeTablet;
              isPortrait = context.isPortrait;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isLargeTablet, isTrue);
      expect(isPortrait, isTrue);
    });
  });
}
