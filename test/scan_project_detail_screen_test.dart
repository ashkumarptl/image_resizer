import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/core/constants/app_colors.dart';
import 'package:image_resizer/data/models/scan_project.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/presentation/scan_to_pdf/scan_page_preview_screen.dart';
import 'package:image_resizer/presentation/scan_to_pdf/scan_project_detail_screen.dart';
import 'package:image_resizer/services/auth_service.dart';

class MockAuthService extends AuthService {
  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);

  @override
  User? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File samplePage1;
  late File samplePage2;
  late File samplePage3;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('detail_test_');
    samplePage1 = File('${tempDir.path}/page1.jpg')..writeAsStringSync('page1');
    samplePage2 = File('${tempDir.path}/page2.jpg')..writeAsStringSync('page2');
    samplePage3 = File('${tempDir.path}/page3.jpg')..writeAsStringSync('page3');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('ScanProjectDetailScreen displays project name, pages, and CamScanner buttons',
      (WidgetTester tester) async {
    final project = ScanProject(
      id: 'test_project',
      name: 'College Certificates',
      pagePaths: [samplePage1.path, samplePage2.path],
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

    // Verify Title & Page count
    expect(find.text('College Certificates'), findsOneWidget);
    expect(find.text('2 PAGES'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);

    // Verify outer page cards show clean images without cluttered edit/replace buttons
    expect(find.text('Studio Edit'), findsNothing);
    expect(find.text('Replace'), findsNothing);

    // Tapping a page opens ScanPagePreviewScreen where Edit, Replace, and Save to Gallery are available
    await tester.tap(find.text('1/2'));
    await tester.pumpAndSettle();
    expect(find.text('Studio Edit'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Save to Gallery'), findsOneWidget);

    // Return to detail screen
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // Verify Bottom action buttons
    expect(find.text('Add Pages'), findsOneWidget);
    expect(find.text('Save PDF'), findsOneWidget);

    // Verify Target PDF Size Selector chip in banner
    expect(find.byKey(const ValueKey('target_pdf_size_chip')), findsOneWidget);
    expect(find.text('Medium (< 2 MB)'), findsOneWidget);

    // Open Target PDF Size modal
    await tester.tap(find.byKey(const ValueKey('target_pdf_size_chip')));
    await tester.pumpAndSettle();

    // Verify presets shown in bottom sheet
    expect(find.text('Target PDF Size'), findsOneWidget);
    expect(find.text('Low (< 1 MB)'), findsOneWidget);
    expect(find.text('Original (HQ)'), findsOneWidget);

    // Tap Medium preset to dismiss sheet without triggering async PDF recompilation
    await tester.tap(find.text('Medium (< 2 MB)').last);
    await tester.pumpAndSettle();

    // Verify View mode toggle (List <-> Grid)
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    // In Grid view, icons and layout switch to SmoothReorderableGrid (grid_view_smooth_grid)
    expect(find.byIcon(Icons.view_agenda_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('grid_view_smooth_grid')), findsOneWidget);

    // Switch back to List View
    await tester.tap(find.byIcon(Icons.view_agenda_rounded));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('list_view_smooth_grid')), findsOneWidget);
  });

  testWidgets('Metadata banner does not overflow RenderFlex on narrow mobile screens (360px and 320px)',
      (WidgetTester tester) async {
    final project = ScanProject(
      id: 'narrow_test_project',
      name: 'Passport & Visa',
      pagePaths: [samplePage1.path, samplePage2.path],
      pdfPath: samplePage1.path,
      pdfQuality: 'medium',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Test on 360px wide screen (standard Android)
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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

    // Verify no flutter exceptions or overflow errors were thrown
    expect(tester.takeException(), isNull);
    expect(find.text('2 PAGES'), findsOneWidget);
    expect(find.byKey(const ValueKey('target_pdf_size_chip')), findsOneWidget);

    // Test on even narrower 320px screen
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ScanPagePreviewScreen adapts properly to light theme and dark theme',
      (WidgetTester tester) async {
    final project = ScanProject(
      id: 'theme_test_project',
      name: 'Theme Document',
      pagePaths: [samplePage1.path],
      pdfPath: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 1. Test Light Theme
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          home: ScanPagePreviewScreen(project: project),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lightScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(lightScaffold.backgroundColor, const Color(0xFFF1F5F9));
    final lightAppBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(lightAppBar.backgroundColor, AppColors.surfaceLight);

    // 2. Test Dark Theme
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: ScanPagePreviewScreen(project: project),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final darkScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(darkScaffold.backgroundColor, AppColors.backgroundDark);
    final darkAppBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(darkAppBar.backgroundColor, AppColors.surfaceDark);
  });

  testWidgets('ScanPagePreviewScreen renders tablet floating dock and navigation chevrons on tablets',
      (WidgetTester tester) async {
    final project = ScanProject(
      id: 'tablet_project',
      name: 'Tablet Document',
      pagePaths: [samplePage1.path, samplePage2.path],
      pdfPath: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Set tablet physical size (800x1280 iPad / Android Tablet)
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: MaterialApp(
          home: ScanPagePreviewScreen(project: project),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify tablet next page chevron is present
    expect(find.byTooltip('Next Page'), findsOneWidget);

    // Verify all 4 action buttons are present in the tablet floating dock
    expect(find.text('Studio Edit'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Save to Gallery'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Tap next page chevron to navigate to page 2
    await tester.tap(find.byTooltip('Next Page'));
    await tester.pumpAndSettle();

    // Verify previous page chevron is now visible on page 2
    expect(find.byTooltip('Previous Page'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('ScanProjectDetailScreen supports multi-selection and CamScanner-style group drag',
      (WidgetTester tester) async {
    final project = ScanProject(
      id: 'multiselect_project',
      name: 'Receipts',
      pagePaths: [samplePage1.path, samplePage2.path],
      pdfPath: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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

    // Switch to Grid View
    await tester.tap(find.byTooltip('Grid View'));
    await tester.pumpAndSettle();

    // Verify grid cards '01' and '02' are visible
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);

    // Long-press page '01' to enter selection mode
    final g1 = await tester.startGesture(tester.getCenter(find.text('01')));
    await tester.pump(const Duration(milliseconds: 600));
    await g1.up();
    await tester.pumpAndSettle();

    // Verify selection AppBar is active
    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.byTooltip('Cancel Selection'), findsOneWidget);

    // Tap page 02 to select it as well
    await tester.tap(find.text('02'));
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);

    // Cancel selection
    await tester.tap(find.byTooltip('Cancel Selection'));
    await tester.pumpAndSettle();
    expect(find.text('Receipts'), findsOneWidget);
    expect(find.text('2 Selected'), findsNothing);
  });

  testWidgets('ScanProjectDetailScreen holding a page enters multi-select mode directly',
      (WidgetTester tester) async {
    final project = ScanProject(
      id: 'hold_multiselect_project',
      name: 'Tax Forms',
      pagePaths: [samplePage1.path, samplePage2.path],
      pdfPath: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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

    // Switch to Grid View
    await tester.tap(find.byTooltip('Grid View'));
    await tester.pumpAndSettle();

    // Verify initially in normal mode
    expect(find.text('Tax Forms'), findsOneWidget);
    expect(find.text('1 Selected'), findsNothing);

    // Hold (long-press) on page '01'
    final gesture = await tester.startGesture(tester.getCenter(find.text('01')));
    await tester.pump(const Duration(milliseconds: 600));

    // Release gesture
    await gesture.up();
    await tester.pumpAndSettle();

    // Holding page '01' has put screen directly into multi-select mode!
    expect(find.text('1 Selected'), findsOneWidget);

    // Now simply tap page '02' to add to selection
    await tester.tap(find.text('02'));
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);
  });

  testWidgets('dragging unselected page resets previous selection and selects only dragged page',
      (WidgetTester tester) async {
    final project = ScanProject(
      id: 'reset_on_unselected_drag_project',
      name: 'Work Invoices',
      pagePaths: [samplePage1.path, samplePage2.path, samplePage3.path],
      pdfPath: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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

    // Switch to Grid View
    await tester.tap(find.byTooltip('Grid View'));
    await tester.pumpAndSettle();

    // Select page '01' via long-press
    final g1 = await tester.startGesture(tester.getCenter(find.text('01')));
    await tester.pump(const Duration(milliseconds: 600));
    await g1.up();
    await tester.pumpAndSettle();
    expect(find.text('1 Selected'), findsOneWidget);

    // Tap page '02' to select it as well (now 01 and 02 are selected)
    await tester.tap(find.text('02'));
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);

    // Now user tries to drag unselected page '03'
    // Previous selection {01, 02} MUST be reset, and only '03' selected (count = 1)
    final g3 = await tester.startGesture(tester.getCenter(find.text('03')));
    await tester.pump(const Duration(milliseconds: 600));

    // Selection count is now 1 (only page 03 is selected)
    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.text('2 Selected'), findsNothing);

    // Release gesture
    await g3.up();
    await tester.pumpAndSettle();

    // Selected count remains 1
    expect(find.text('1 Selected'), findsOneWidget);
  });

  testWidgets('List View supports CamScanner-style multi-select group drag and drop',
      (WidgetTester tester) async {
    final project = ScanProject(
      id: 'list_view_group_drag_project',
      name: 'Legal Documents',
      pagePaths: [samplePage1.path, samplePage2.path, samplePage3.path],
      pdfPath: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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

    // Default view is List View
    expect(find.byKey(const ValueKey('list_view_smooth_grid')), findsOneWidget);

    // Long press on page '1/3' card
    final g1 = await tester.startGesture(tester.getCenter(find.text('1/3')));
    await tester.pump(const Duration(milliseconds: 600));
    await g1.up();
    await tester.pumpAndSettle();

    // Enters multi-select mode
    expect(find.text('1 Selected'), findsOneWidget);

    // Tap page '2/3' card to add to selection
    await tester.tap(find.text('2/3'));
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);

    // Now start group drag on selected page '2/3'
    final dragGesture = await tester.startGesture(tester.getCenter(find.text('2/3')));
    await tester.pump(const Duration(milliseconds: 600));

    // Multiple placeholders gaps should exist
    expect(find.byKey(const ValueKey('grid_placeholder_gap')), findsOneWidget);
    expect(find.byKey(const ValueKey('grid_placeholder_gap_1')), findsOneWidget);

    // Count badge '2' is visible on the stacked drag preview
    expect(find.text('2'), findsOneWidget);

    // Move downwards to reorder
    await dragGesture.moveBy(const Offset(0, 450));
    await tester.pump(const Duration(milliseconds: 50));

    // Release gesture
    await dragGesture.up();
    await tester.pumpAndSettle();

    // Verify selection remains active with 2 selected
    expect(find.text('2 Selected'), findsOneWidget);

    // Cancel selection and verify document title restored
    await tester.tap(find.byTooltip('Cancel Selection'));
    await tester.pumpAndSettle();
    expect(find.text('Legal Documents'), findsOneWidget);
  });

  testWidgets(
      'multi-selection shows Share and Save to Device options in bottom bar (not in top AppBar)',
      (WidgetTester tester) async {
    final project = ScanProject(
      id: 'multiselect_share_save_project',
      name: 'Certificates',
      pagePaths: [samplePage1.path, samplePage2.path],
      pdfPath: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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

    // Switch to Grid View
    await tester.tap(find.byTooltip('Grid View'));
    await tester.pumpAndSettle();

    // Long press page 01 to enter selection mode
    final g1 = await tester.startGesture(tester.getCenter(find.text('01')));
    await tester.pump(const Duration(milliseconds: 600));
    await g1.up();
    await tester.pumpAndSettle();

    // Verify selection mode is active
    expect(find.text('1 Selected'), findsOneWidget);

    // Verify action buttons are at the bottom and NOT cluttered in the top AppBar
    expect(find.byTooltip('Share Selected'), findsNothing);
    expect(find.byTooltip('Save Selected to Device'), findsNothing);
    expect(find.text('Share (1)'), findsOneWidget);
    expect(find.text('Save to Device'), findsOneWidget);
    expect(find.byTooltip('Print Selected'), findsOneWidget); // In bottom bar
    expect(find.byTooltip('Delete Selected'), findsOneWidget); // In bottom bar

    // Tap Save to Device button at bottom to open format options bottom sheet
    await tester.tap(find.text('Save to Device'));
    await tester.pumpAndSettle();

    expect(find.text('Save 1 Selected Page to Device'), findsOneWidget);
    expect(find.text('Save to Photos / Gallery'), findsOneWidget);
    expect(find.text('Save as PDF to Downloads'), findsOneWidget);

    // Tap Cancel/scrim to dismiss sheet
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Tap Share (1) at bottom to open share format options bottom sheet
    await tester.tap(find.text('Share (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Share 1 Selected Page'), findsOneWidget);
    expect(find.text('Share as PDF Document'), findsOneWidget);
    expect(find.text('Share as Image Files'), findsOneWidget);
    expect(find.text('Send to PC / Browser'), findsOneWidget);
  });

  testWidgets('ScanProjectDetailScreen has Print Document in more menu and ScanPagePreviewScreen has Print Page button',
      (WidgetTester tester) async {
    final project = ScanProject(
      id: 'print_menu_project',
      name: 'Passport Docs',
      pagePaths: [samplePage1.path],
      pdfPath: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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

    // Tap 3-dots popup menu
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    // Verify Print Document and Send to PC menu items are present
    expect(find.text('Print Document'), findsOneWidget);
    expect(find.text('Send to PC (Cyber Cafe)'), findsOneWidget);

    // Dismiss menu
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Now test ScanPagePreviewScreen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: MaterialApp(
          home: ScanPagePreviewScreen(project: project, initialIndex: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Print Page button exists in AppBar
    expect(find.byTooltip('Print Page'), findsOneWidget);
  });
}




