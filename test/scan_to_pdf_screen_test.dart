import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/models/scan_project.dart';
import 'package:image_resizer/data/repositories/auth_repository.dart';
import 'package:image_resizer/presentation/scan_to_pdf/scan_to_pdf_screen.dart';
import 'package:image_resizer/services/auth_service.dart';

class MockAuthService extends AuthService {
  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);

  @override
  User? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ScanToPdfScreen renders header with offline badge, quick action cards, and search bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: const MaterialApp(
          home: ScanToPdfScreen(isTab: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Scan to PDF'), findsWidgets);
    expect(find.text('Auto-deskew, enhance & convert to PDF'), findsOneWidget);

    // Verify Offline Badge
    expect(find.text('Offline'), findsOneWidget);

    // Verify Quick Action cards
    expect(find.text('Scan\nDocument'), findsOneWidget);
    expect(find.text('Import\nImages'), findsOneWidget);

    // Verify Search bar
    expect(find.text('Search documents, notes, etc...'), findsOneWidget);

    // Verify New Scan FAB is present
    expect(find.text('New Scan'), findsOneWidget);

    // Verify Feature badges
    expect(find.text('⚡ Auto Boundary'), findsOneWidget);
    expect(find.text('🌓 Shadow Clean'), findsOneWidget);
    expect(find.text('📑 Multi-Page PDF'), findsOneWidget);
    expect(find.text('🔒 100% Offline'), findsOneWidget);

    // Verify Tips card
    expect(find.text('Tips for Best PDF Scans'), findsOneWidget);
    expect(find.textContaining('Contrast Background', findRichText: true), findsOneWidget);
  });

  testWidgets('ScanToPdfScreen project card renders cleanly on small screens without overflow',
      (WidgetTester tester) async {
    final project = ScanProject(
      id: 'test_nona',
      name: 'Nona Document Project',
      pagePaths: ['/dummy/page1.jpg', '/dummy/page2.jpg'],
      pdfPath: null,
      createdAt: DateTime(2026, 9, 8),
      updatedAt: DateTime(2026, 9, 8),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 640)),
            child: SizedBox(
              width: 360,
              height: 640,
              child: ScanToPdfScreen(
                isTab: true,
                initialProjects: [project],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nona Document Project'), findsOneWidget);
    expect(find.text('2 Pages'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ScanToPdfScreen search filters projects in real time',
      (WidgetTester tester) async {
    final project1 = ScanProject(
      id: 'doc1',
      name: 'Passport Copy',
      pagePaths: ['/dummy/page1.jpg'],
      createdAt: DateTime(2026, 9, 8),
      updatedAt: DateTime(2026, 9, 8),
    );
    final project2 = ScanProject(
      id: 'doc2',
      name: 'Electric Bill',
      pagePaths: ['/dummy/page2.jpg'],
      createdAt: DateTime(2026, 9, 9),
      updatedAt: DateTime(2026, 9, 9),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: MaterialApp(
          home: ScanToPdfScreen(
            isTab: true,
            initialProjects: [project1, project2],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Passport Copy'), findsOneWidget);
    expect(find.text('Electric Bill'), findsOneWidget);

    // Type in search bar
    await tester.enterText(find.byType(TextField), 'Passport');
    await tester.pumpAndSettle();

    expect(find.text('Passport Copy'), findsOneWidget);
    expect(find.text('Electric Bill'), findsNothing);
  });

  testWidgets('ScanToPdfScreen filter bottom sheet opens without Material assertion error',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: const MaterialApp(
          home: ScanToPdfScreen(isTab: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap filter button
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    // Verify sort options render cleanly without framework exceptions
    expect(find.text('Sort Documents'), findsOneWidget);
    expect(find.text('Newest first (Default)'), findsOneWidget);
    expect(find.text('Name (A-Z)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tap a sort option and verify it closes
    await tester.tap(find.text('Name (A-Z)'));
    await tester.pumpAndSettle();

    expect(find.text('Sort Documents'), findsNothing);
  });
}


