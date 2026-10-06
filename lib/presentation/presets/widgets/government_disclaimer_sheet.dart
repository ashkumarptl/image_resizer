import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radii.dart';
import '../../../core/layout/adaptive_layout.dart';

class OfficialSourceItem {
  final String title;
  final String url;
  final String category;

  const OfficialSourceItem({
    required this.title,
    required this.url,
    required this.category,
  });
}

class GovernmentDisclaimerSheet extends StatelessWidget {
  const GovernmentDisclaimerSheet({super.key});

  static const List<OfficialSourceItem> officialSources = [
    OfficialSourceItem(
      title: 'Staff Selection Commission (SSC)',
      url: 'https://ssc.gov.in',
      category: 'Central Recruitment',
    ),
    OfficialSourceItem(
      title: 'Union Public Service Commission (UPSC)',
      url: 'https://upsc.gov.in',
      category: 'Central Recruitment',
    ),
    OfficialSourceItem(
      title: 'Railway Recruitment Boards (RRB)',
      url: 'https://indianrailways.gov.in',
      category: 'Railways',
    ),
    OfficialSourceItem(
      title: 'Institute of Banking Personnel Selection (IBPS)',
      url: 'https://www.ibps.in',
      category: 'Banking',
    ),
    OfficialSourceItem(
      title: 'CG Vyapam (Chhattisgarh)',
      url: 'https://vyapam.cgstate.gov.in',
      category: 'State PSC / Vyapam',
    ),
    OfficialSourceItem(
      title: 'UPPSC (Uttar Pradesh)',
      url: 'https://uppsc.up.nic.in',
      category: 'State PSC',
    ),
    OfficialSourceItem(
      title: 'MPPSC (Madhya Pradesh)',
      url: 'https://mppsc.mp.gov.in',
      category: 'State PSC',
    ),
    OfficialSourceItem(
      title: 'BPSC (Bihar)',
      url: 'https://bpsc.bih.nic.in',
      category: 'State PSC',
    ),
    OfficialSourceItem(
      title: 'Passport Seva Portal',
      url: 'https://www.passportindia.gov.in',
      category: 'Identity & Passports',
    ),
    OfficialSourceItem(
      title: 'UIDAI (Aadhaar Guidelines)',
      url: 'https://uidai.gov.in',
      category: 'Identity',
    ),
    OfficialSourceItem(
      title: 'Income Tax Department (PAN)',
      url: 'https://incometax.gov.in',
      category: 'Identity',
    ),
    OfficialSourceItem(
      title: 'National Portal of India',
      url: 'https://www.india.gov.in',
      category: 'General Government Portal',
    ),
  ];

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const GovernmentDisclaimerSheet(),
    );
  }

  Future<void> _openUrl(BuildContext context, String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $urlString')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.25 : 0.12,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disclaimer & Official Sources',
                        style: TextStyle(
                          fontSize: context.adaptiveFontSize(
                            16,
                            tabletSize: 18,
                          ),
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Government Information & Compliance Notice',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                // Non-Affiliation Disclaimer Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(AppRadii.cardSmall),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFB45309),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Non-Government Affiliation Disclaimer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Image Tools is an independent utility application developed by Ash Spark. '
                              'This application is NOT affiliated with, endorsed by, authorized by, '
                              'or in any official way connected with any government entity, recruitment commission, or public board.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: const Color(
                                  0xFF78350F,
                                ).withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Source Reference Explanation
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceVariantDark
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(AppRadii.cardSmall),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sources of Specifications & Guidelines',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All preset specifications (pixel dimensions, aspect ratios, file-size limits, and DPI) provided in this app are reference templates based on publicly accessible recruitment notices and guidelines published on official government websites. Always verify requirements in your official examination notification.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Official Sources List Heading
                Text(
                  'Official Government & Examination Portals',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),

                ...officialSources.map((source) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isDark
                          ? AppColors.surfaceVariantDark
                          : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.cardSmall),
                      child: InkWell(
                        onTap: () => _openUrl(context, source.url),
                        borderRadius: BorderRadius.circular(AppRadii.cardSmall),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppRadii.cardSmall,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: isDark ? 0.2 : 0.08,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.public_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      source.title,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      source.url,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Persistent Bottom Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.cardSmall),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'I Understand',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
