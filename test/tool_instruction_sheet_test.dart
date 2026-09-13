import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/repositories/tool_guide_repository.dart';
import 'package:image_resizer/presentation/widgets/tool_instruction_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolGuideRepository & Data Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('All ToolGuideType values have complete guide configurations', () {
      for (final type in ToolGuideType.values) {
        final data = ToolGuideData.getGuide(type);
        expect(data.title.isNotEmpty, isTrue, reason: 'Title for ${type.name} is empty');
        expect(data.subtitle.isNotEmpty, isTrue, reason: 'Subtitle for ${type.name} is empty');
        expect(data.proTip.isNotEmpty, isTrue, reason: 'ProTip for ${type.name} is empty');
        expect(data.steps.length, greaterThanOrEqualTo(3),
            reason: 'Steps for ${type.name} should be at least 3');

        for (final step in data.steps) {
          expect(step.title.isNotEmpty, isTrue);
          expect(step.description.isNotEmpty, isTrue);
          expect(step.stepNumber, greaterThan(0));
        }
      }
    });

    test('ToolGuideRepository tracks seen status and resets correctly', () async {
      final repo = ToolGuideRepository();

      // Initially, guide should be shown
      expect(await repo.shouldShowGuide(ToolGuideType.signatureCleaner), isTrue);

      // Mark as seen
      await repo.markGuideAsSeen(ToolGuideType.signatureCleaner);
      expect(await repo.shouldShowGuide(ToolGuideType.signatureCleaner), isFalse);

      // Other guides remain unaffected
      expect(await repo.shouldShowGuide(ToolGuideType.editStudio), isTrue);

      // Reset single guide
      await repo.resetGuide(ToolGuideType.signatureCleaner);
      expect(await repo.shouldShowGuide(ToolGuideType.signatureCleaner), isTrue);

      // Mark multiple as seen and reset all
      await repo.markGuideAsSeen(ToolGuideType.signatureCleaner);
      await repo.markGuideAsSeen(ToolGuideType.editStudio);
      expect(await repo.shouldShowGuide(ToolGuideType.signatureCleaner), isFalse);
      expect(await repo.shouldShowGuide(ToolGuideType.editStudio), isFalse);

      await repo.resetAllGuides();
      expect(await repo.shouldShowGuide(ToolGuideType.signatureCleaner), isTrue);
      expect(await repo.shouldShowGuide(ToolGuideType.editStudio), isTrue);
    });
  });

  group('ToolInstructionSheet Widget Tests', () {
    testWidgets('renders all steps, pro tip, and calls onDismiss', (tester) async {
      bool dismissed = false;
      final guide = ToolGuideData.getGuide(ToolGuideType.signatureCleaner);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolInstructionSheet(
                guideData: guide,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );

      // Settle animations
      await tester.pumpAndSettle();

      // Verify title & subtitle
      expect(find.text(guide.title), findsOneWidget);
      expect(find.text(guide.subtitle), findsOneWidget);

      // Verify steps
      for (final step in guide.steps) {
        expect(find.text(step.title), findsOneWidget);
      }

      // Verify Pro Tip in RichText
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('Pro Tip:'),
        ),
        findsOneWidget,
      );

      // Verify action button and tap
      final buttonFinder = find.text('Got it, Let\'s Start');
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      expect(dismissed, isTrue);
    });
  });
}
