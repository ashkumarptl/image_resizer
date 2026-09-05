import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/usage_limit_repository.dart';
import 'account_section.dart';

/// Helper function to check if the user can use a feature.
/// Returns `true` if authorized (either signed in or within free guest limit).
/// If free limit is exhausted, displays the Login Gate bottom sheet and returns
/// `true` only if the user logs in.
Future<bool> checkFeatureAccess(BuildContext context, WidgetRef ref) async {
  final isDeveloper = ref.read(isDeveloperProvider);
  if (isDeveloper) {
    return true;
  }

  final user = ref.read(currentUserProvider);
  if (user != null) {
    return true;
  }

  final isLimitReached = ref.read(isUsageLimitReachedProvider);
  if (!isLimitReached) {
    return true;
  }

  // Free limit exhausted: show login gate
  final bool? signedIn = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const LoginGateBottomSheet(),
  );

  return signedIn == true;
}

/// A bottom sheet modal shown when a guest user exceeds their free usages.
class LoginGateBottomSheet extends ConsumerStatefulWidget {
  const LoginGateBottomSheet({super.key});

  @override
  ConsumerState<LoginGateBottomSheet> createState() => _LoginGateBottomSheetState();
}

class _LoginGateBottomSheetState extends ConsumerState<LoginGateBottomSheet> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final cred = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;
      if (cred?.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Welcome ${cred!.user?.displayName ?? 'User'}! Unlimited access unlocked.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Sign-In failed: ${e.message ?? e.code}'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not sign in: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon Badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Free Trial Limit Reached',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            'You have used your ${AppConstants.maxFreeGuestUses} free trials. Sign in with Google to continue using all tools with unlimited access!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),

          // Benefits List
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : AppColors.primaryContainerLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              children: [
                _buildBenefitRow(Icons.all_inclusive_rounded, 'Unlimited Image Resizing & Compressing', isDark),
                const SizedBox(height: 8),
                _buildBenefitRow(Icons.bolt_rounded, 'Batch Processing & ZIP Downloads', isDark),
                const SizedBox(height: 8),
                _buildBenefitRow(Icons.account_balance_rounded, 'All Indian Govt & Exam Presets', isDark),
                const SizedBox(height: 8),
                _buildBenefitRow(Icons.check_circle_outline_rounded, '100% Free Forever with Google', isDark),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Google Sign-In Button
          GoogleSignInButton(
            text: 'Sign In to Unlock Unlimited',
            isLoading: _isLoading,
            onPressed: _handleGoogleSignIn,
          ),
          const SizedBox(height: 12),

          // Cancel / Dismiss
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
            child: Text(
              'Maybe Later',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
