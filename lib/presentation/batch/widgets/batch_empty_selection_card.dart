import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Card displayed when no images are selected in Batch Mode
class BatchEmptySelectionCard extends StatelessWidget {
  final VoidCallback onSmartScannerPressed;
  final VoidCallback onGalleryPressed;

  const BatchEmptySelectionCard({
    super.key,
    required this.onSmartScannerPressed,
    required this.onGalleryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryContainerLight.withValues(
                alpha: isDark ? 0.2 : 0.6,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              size: 38,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Multiple Images',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose up to 50 photos to compress, resize, and convert in bulk.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onSmartScannerPressed,
                  icon: const Icon(Icons.document_scanner_rounded, size: 20),
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Smart Document Scanner',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      _MlKitBadge(),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onGalleryPressed,
                  icon: const Icon(
                    Icons.photo_library_rounded,
                    size: 18,
                    color: Color(0xFF10B981),
                  ),
                  label: const Text(
                    'Import from Gallery',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MlKitBadge extends StatelessWidget {
  const _MlKitBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'ML KIT',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: Colors.white,
        ),
      ),
    );
  }
}
