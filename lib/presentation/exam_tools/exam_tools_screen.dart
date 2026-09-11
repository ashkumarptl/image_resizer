import 'package:flutter/material.dart';
import '../presets/presets_hub_screen.dart';

/// Combined Exam Tools & Presets Screen delegate.
///
/// Forwards directly to [PresetsHubScreen] opened to the Exam Tools tab.
class ExamToolsScreen extends StatelessWidget {
  final VoidCallback? onNavigateToPresets;

  const ExamToolsScreen({
    super.key,
    this.onNavigateToPresets,
  });

  @override
  Widget build(BuildContext context) {
    return const PresetsHubScreen(isTab: false, initialTabIndex: 0);
  }
}
