import 'package:flutter/material.dart';

/// Single feature highlight inside an onboarding page
class OnboardingFeatureItem {
  final String title;
  final String description;
  final IconData icon;
  final String? badge;
  final Color accentColor;

  const OnboardingFeatureItem({
    required this.title,
    required this.description,
    required this.icon,
    this.badge,
    required this.accentColor,
  });
}

/// Information configuration for each of the 3 onboarding pages
class OnboardingPageData {
  final int pageIndex;
  final String badge;
  final String title;
  final String subtitle;
  final IconData heroIcon;
  final List<Color> gradientColors;
  final List<OnboardingFeatureItem> features;

  const OnboardingPageData({
    required this.pageIndex,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.heroIcon,
    required this.gradientColors,
    required this.features,
  });

  /// The 3 pre-defined onboarding pages
  static List<OnboardingPageData> get pages => [
    // Page 1: Edit Studio
    const OnboardingPageData(
      pageIndex: 0,
      badge: 'ALL-IN-ONE EDIT STUDIO',
      title: 'Photo & Image Studio',
      subtitle:
          'Powerful, professional photo compression, resizing, background removal & format conversion tools.',
      heroIcon: Icons.tune_rounded,
      gradientColors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
      features: [
        OnboardingFeatureItem(
          title: 'Smart Target Size Compressor',
          description:
              'Compress images to exact KB (20 KB, 50 KB, 100 KB, 200 KB or custom) without losing clarity.',
          icon: Icons.compress_rounded,
          badge: 'Exact KB/MB',
          accentColor: Color(0xFF2563EB),
        ),
        OnboardingFeatureItem(
          title: 'Pixel & Print DPI Resizer',
          description:
              'Resize by exact pixel dimensions (W × H), percentage scale, or print sizes (cm / inch) with aspect ratio lock.',
          icon: Icons.open_in_full_rounded,
          badge: 'Pixels & DPI',
          accentColor: Color(0xFF0284C7),
        ),
        OnboardingFeatureItem(
          title: 'Multi-Format Converter',
          description:
              'Convert seamlessly between JPG, PNG, and WebP with fine quality control & lossless options.',
          icon: Icons.transform_rounded,
          badge: 'JPG • PNG • WebP',
          accentColor: Color(0xFF0D9488),
        ),
        OnboardingFeatureItem(
          title: 'AI Background Remover',
          description:
              '1-tap AI cutout to isolate portraits, objects & signatures with transparent or custom solid backgrounds.',
          icon: Icons.auto_fix_high_rounded,
          badge: 'AI Powered',
          accentColor: Color(0xFF7C3AED),
        ),
        OnboardingFeatureItem(
          title: 'AI Super-Resolution Upscale',
          description:
              'Enhance low-resolution photos and recover fine details using 2x or 4x neural network upscaling.',
          icon: Icons.auto_awesome_rounded,
          badge: 'Super-Res',
          accentColor: Color(0xFFDB2777),
        ),
        OnboardingFeatureItem(
          title: 'Doc Clean Filter & Crop',
          description:
              'Enhance scanned documents, remove dark shadows, crop to standard aspect ratios, rotate 90°, and mirror flip.',
          icon: Icons.crop_rotate_rounded,
          badge: 'Doc Filter & Crop',
          accentColor: Color(0xFFD97706),
        ),
      ],
    ),

    // Page 2: Scan to PDF
    const OnboardingPageData(
      pageIndex: 1,
      badge: 'DOCUMENT SCANNER',
      title: 'Scan to PDF Studio',
      subtitle:
          'Turn physical papers, bills, receipts, certificates & IDs into crisp, compact, multi-page PDFs.',
      heroIcon: Icons.picture_as_pdf_rounded,
      gradientColors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
      features: [
        OnboardingFeatureItem(
          title: 'Multi-Page Smart Scanner',
          description:
              'High-res camera capture with automatic document edge detection or bulk import from gallery.',
          icon: Icons.document_scanner_rounded,
          badge: 'Camera & Gallery',
          accentColor: Color(0xFFE11D48),
        ),
        OnboardingFeatureItem(
          title: 'Smart PDF Size Optimizer',
          description:
              'Optimize PDF file size with balanced compression to meet strict job portal & email limits (<1 MB, 2 MB).',
          icon: Icons.inventory_2_outlined,
          badge: 'Compact PDF',
          accentColor: Color(0xFF9333EA),
        ),
        OnboardingFeatureItem(
          title: 'Drag & Drop Page Reorder',
          description:
              'Organize pages effortlessly with smooth drag & drop, rotate individual pages, and batch delete.',
          icon: Icons.low_priority_rounded,
          badge: 'Reorder & Edit',
          accentColor: Color(0xFF0284C7),
        ),
        OnboardingFeatureItem(
          title: 'Project Library & Search',
          description:
              'Keep all your documents safely stored in organized projects with quick search and sorting by date or size.',
          icon: Icons.folder_special_outlined,
          badge: 'Saved Projects',
          accentColor: Color(0xFF0D9488),
        ),
        OnboardingFeatureItem(
          title: 'Wireless Print & Instant Share',
          description:
              'Print directly via WiFi or export and share instantly over WhatsApp, Gmail, Drive, and Files.',
          icon: Icons.share_rounded,
          badge: 'Print & Share',
          accentColor: Color(0xFF16A34A),
        ),
        OnboardingFeatureItem(
          title: 'In-Studio Page Refinement',
          description:
              'Jump from any document page directly into Edit Studio for precise cropping and contrast enhancement.',
          icon: Icons.tune_rounded,
          badge: 'Studio Linked',
          accentColor: Color(0xFFEA580C),
        ),
      ],
    ),

    // Page 3: Exam Tools & Presets
    const OnboardingPageData(
      pageIndex: 2,
      badge: 'GOVT & EXAM READY',
      title: 'Exam Tools & Presets',
      subtitle:
          'Official dimension presets and specialized utilities tailored for Indian Govt & Competitive Exam portals.',
      heroIcon: Icons.verified_outlined,
      gradientColors: [Color(0xFF059669), Color(0xFF10B981)],
      features: [
        OnboardingFeatureItem(
          title: '50+ Govt & Exam Presets',
          description:
              '1-tap exact dimensions (W × H) and strict KB limits for SSC, UPSC, IBPS, State PSC, Defence & IDs.',
          icon: Icons.checklist_rounded,
          badge: '50+ Presets',
          accentColor: Color(0xFF059669),
        ),
        OnboardingFeatureItem(
          title: 'Signature B&W Cleaner',
          description:
              'Converts paper signatures into pure monochrome ink. Removes paper shadows, texture & tint (<20 KB ready).',
          icon: Icons.draw_rounded,
          badge: 'Clean <20 KB',
          accentColor: Color(0xFF0D9488),
        ),
        OnboardingFeatureItem(
          title: 'Name & Date Photo Stamp',
          description:
              'Imprints candidate name and Date of Photo (DOP) on passport photos with the mandatory white label.',
          icon: Icons.badge_outlined,
          badge: 'Official Stamp',
          accentColor: Color(0xFFEA580C),
        ),
        OnboardingFeatureItem(
          title: 'Perspective Crop & Deskew',
          description:
              '4-corner keystone document straightener to flatten angled shots of marksheets, IDs & certificates.',
          icon: Icons.crop_rotate_rounded,
          badge: 'Auto-Deskew',
          accentColor: Color(0xFF2563EB),
        ),
        OnboardingFeatureItem(
          title: '100% Offline & Private',
          description:
              'Zero data leaves your phone. All image and PDF processing is executed 100% locally on your device.',
          icon: Icons.shield_outlined,
          badge: '100% Private',
          accentColor: Color(0xFF16A34A),
        ),
      ],
    ),
  ];
}
