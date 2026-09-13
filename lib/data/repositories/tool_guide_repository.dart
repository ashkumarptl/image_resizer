import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum representing each individual tool that has a guided instruction walkthrough
enum ToolGuideType {
  editStudio,
  signatureCleaner,
  perspectiveCrop,
  photoStamp,
  aiUpscaler,
  documentFilter,
  scanToPdf,
}

/// Single instruction step in a tool's guide
class ToolInstructionStep {
  final int stepNumber;
  final String title;
  final String description;
  final IconData icon;

  const ToolInstructionStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Comprehensive guide data for a tool
class ToolGuideData {
  final ToolGuideType type;
  final String title;
  final String subtitle;
  final IconData toolIcon;
  final Color accentColor;
  final List<ToolInstructionStep> steps;
  final String proTip;

  const ToolGuideData({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.toolIcon,
    required this.accentColor,
    required this.steps,
    required this.proTip,
  });

  /// Static registry providing guided content for all supported tools
  static ToolGuideData getGuide(ToolGuideType type) {
    switch (type) {
      case ToolGuideType.editStudio:
        return const ToolGuideData(
          type: ToolGuideType.editStudio,
          title: 'Photo & Image Studio',
          subtitle: 'Professional resizing, compression & enhancement',
          toolIcon: Icons.tune_rounded,
          accentColor: Color(0xFF2563EB),
          steps: [
            ToolInstructionStep(
              stepNumber: 1,
              title: 'Choose Target Size or Dimensions',
              description:
                  'Select exact KB (20 KB, 50 KB, 100 KB, 200 KB) or customize pixel width, height, scale % and DPI.',
              icon: Icons.compress_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 2,
              title: 'Use AI & Smart Refinements',
              description:
                  'Isolate subjects with 1-tap AI Background Remover, upscale low-res photos, or crop to aspect ratios.',
              icon: Icons.auto_fix_high_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 3,
              title: 'Export & Share Instantly',
              description:
                  'Tap the checkmark button to save 100% offline. Use Undo/Redo anytime to compare versions.',
              icon: Icons.check_circle_outline_rounded,
            ),
          ],
          proTip:
              'Double-tap the preview image to zoom in 2.5x for inspecting fine pixel details.',
        );

      case ToolGuideType.signatureCleaner:
        return const ToolGuideData(
          type: ToolGuideType.signatureCleaner,
          title: 'Signature B&W Cleaner',
          subtitle: 'Convert paper signatures to crisp digital ink',
          toolIcon: Icons.draw_rounded,
          accentColor: Color(0xFF0D9488),
          steps: [
            ToolInstructionStep(
              stepNumber: 1,
              title: 'Capture on Plain White Paper',
              description:
                  'Take a clear, well-lit photo of your handwritten signature without heavy shadows.',
              icon: Icons.camera_alt_outlined,
            ),
            ToolInstructionStep(
              stepNumber: 2,
              title: 'Adjust Threshold Slider',
              description:
                  'Slide left or right until all paper grain & yellow tint vanish, leaving only sharp dark ink.',
              icon: Icons.tune_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 3,
              title: 'Select Ink Tone & Save (<20 KB)',
              description:
                  'Choose Dark Navy or Pure Black ink. The output is automatically optimized under 20 KB for UPSC & SSC portals.',
              icon: Icons.verified_outlined,
            ),
          ],
          proTip:
              'Press and hold the "Hold Compare" button anytime to see the original paper photo.',
        );

      case ToolGuideType.perspectiveCrop:
        return const ToolGuideData(
          type: ToolGuideType.perspectiveCrop,
          title: 'Perspective Crop & Deskew',
          subtitle: 'Flatten angled documents, certificates & cards',
          toolIcon: Icons.crop_rotate_rounded,
          accentColor: Color(0xFF3B82F6),
          steps: [
            ToolInstructionStep(
              stepNumber: 1,
              title: 'Position the 4 Corner Pins',
              description:
                  'Drag each circular corner pin to exactly match the 4 edges of your document or card.',
              icon: Icons.touch_app_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 2,
              title: 'Select Aspect Ratio Preset',
              description:
                  'Pick standard A4, ID Card (1.58:1), 4:3, or Freeform to retain the exact real-world proportions.',
              icon: Icons.aspect_ratio_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 3,
              title: 'Keystone Flatten & Deskew',
              description:
                  'Tap the checkmark button to transform the skewed photo into a clean, flat, top-down rectangular scan.',
              icon: Icons.done_all_rounded,
            ),
          ],
          proTip:
              'The magnifying loupe appears as you drag pins so you can align corners with pixel accuracy.',
        );

      case ToolGuideType.photoStamp:
        return const ToolGuideData(
          type: ToolGuideType.photoStamp,
          title: 'Name & Date on Photo',
          subtitle: 'Exam & Admit Card photo labeler',
          toolIcon: Icons.badge_outlined,
          accentColor: Color(0xFFEA580C),
          steps: [
            ToolInstructionStep(
              stepNumber: 1,
              title: 'Enter Candidate Full Name',
              description:
                  'Type your name exactly as registered in the examination application form.',
              icon: Icons.edit_note_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 2,
              title: 'Select Date of Photo (DOP)',
              description:
                  'Pick the photo date. Most portals require a date within 3 months of application submission.',
              icon: Icons.calendar_today_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 3,
              title: 'Set Target KB & Stamp',
              description:
                  'Set target size (e.g., 20 - 50 KB). Generates an official high-contrast white label at the bottom.',
              icon: Icons.verified_rounded,
            ),
          ],
          proTip:
              'Government portals reject photos without standard white background label and clear bold font.',
        );

      case ToolGuideType.aiUpscaler:
        return const ToolGuideData(
          type: ToolGuideType.aiUpscaler,
          title: 'AI Super-Resolution Upscaler',
          subtitle: 'Enhance low-resolution images offline',
          toolIcon: Icons.auto_awesome_rounded,
          accentColor: Color(0xFF8B5CF6),
          steps: [
            ToolInstructionStep(
              stepNumber: 1,
              title: 'Pick Any Low-Res Photo',
              description:
                  'Select a compressed, blurry, or low-resolution photo, signature, or graphic.',
              icon: Icons.photo_library_outlined,
            ),
            ToolInstructionStep(
              stepNumber: 2,
              title: 'Select Neural Scale Factor',
              description:
                  'Choose 2x or 4x super-resolution model according to your target display or print requirements.',
              icon: Icons.zoom_in_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 3,
              title: '100% Offline Processing',
              description:
                  'The AI neural model runs completely on your device hardware without uploading your image anywhere.',
              icon: Icons.shield_outlined,
            ),
          ],
          proTip:
              'Use the split-screen slider in the result view to inspect enhanced edges and texture recovery.',
        );

      case ToolGuideType.documentFilter:
        return const ToolGuideData(
          type: ToolGuideType.documentFilter,
          title: 'Document Clean Filter',
          subtitle: 'Remove paper shadows and enhance text',
          toolIcon: Icons.document_scanner_rounded,
          accentColor: Color(0xFF059669),
          steps: [
            ToolInstructionStep(
              stepNumber: 1,
              title: 'Choose a Filter Preset',
              description:
                  'Select Magic Color, High-Contrast B&W, Grayscale, or Sharpen for optimum readability.',
              icon: Icons.photo_filter_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 2,
              title: 'Preview & Compare Original',
              description:
                  'Hold "Hold to Compare" to instantly compare the enhanced document against the original photo.',
              icon: Icons.compare_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 3,
              title: 'Export Clean Document',
              description:
                  'Save as a crisp document photo ready for printing, official submission, or PDF assembly.',
              icon: Icons.download_done_rounded,
            ),
          ],
          proTip:
              'Tap "Compare" button to quickly toggle between original photo and the filtered document.',
        );

      case ToolGuideType.scanToPdf:
        return const ToolGuideData(
          type: ToolGuideType.scanToPdf,
          title: 'Scan to PDF Studio',
          subtitle: 'Multi-page document scanner & organizer',
          toolIcon: Icons.picture_as_pdf_rounded,
          accentColor: Color(0xFFE11D48),
          steps: [
            ToolInstructionStep(
              stepNumber: 1,
              title: 'Capture or Import Pages',
              description:
                  'Use camera scanner with automatic edge detection or import multiple pages from your gallery.',
              icon: Icons.document_scanner_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 2,
              title: 'Reorder, Rotate & Edit',
              description:
                  'Drag and drop pages to rearrange sequence, rotate orientation, or open in Studio for detailed editing.',
              icon: Icons.low_priority_rounded,
            ),
            ToolInstructionStep(
              stepNumber: 3,
              title: 'Optimize File Size & Share',
              description:
                  'Compress PDF to meet portal upload limits (<1 MB, 2 MB) and share directly via WhatsApp, Drive, or WiFi Print.',
              icon: Icons.share_rounded,
            ),
          ],
          proTip:
              'Save your scans as reusable projects so you can add more pages or re-export anytime.',
        );
    }
  }
}

/// Repository managing whether tool guides have been viewed
class ToolGuideRepository {
  static const String _prefPrefix = 'pref_has_seen_tool_guide_';

  final SharedPreferences? _prefsOverride;

  ToolGuideRepository({SharedPreferences? prefs}) : _prefsOverride = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefsOverride ?? await SharedPreferences.getInstance();
  }

  String _getKey(ToolGuideType type) => '$_prefPrefix${type.name}';

  /// Returns true if the guide should be shown automatically (i.e., user hasn't seen it yet)
  Future<bool> shouldShowGuide(ToolGuideType type) async {
    try {
      final prefs = await _getPrefs();
      final hasSeen = prefs.getBool(_getKey(type)) ?? false;
      return !hasSeen;
    } catch (_) {
      return false;
    }
  }

  /// Mark the guide as seen so it will not pop up automatically again
  Future<void> markGuideAsSeen(ToolGuideType type) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_getKey(type), true);
    } catch (_) {}
  }

  /// Reset a specific guide flag (e.g., for testing or manual re-prompt)
  Future<void> resetGuide(ToolGuideType type) async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_getKey(type));
    } catch (_) {}
  }

  /// Reset all guide flags across all tools
  Future<void> resetAllGuides() async {
    try {
      final prefs = await _getPrefs();
      for (final type in ToolGuideType.values) {
        await prefs.remove(_getKey(type));
      }
    } catch (_) {}
  }
}

/// Global provider for ToolGuideRepository
final toolGuideRepositoryProvider = Provider<ToolGuideRepository>((ref) {
  return ToolGuideRepository();
});
