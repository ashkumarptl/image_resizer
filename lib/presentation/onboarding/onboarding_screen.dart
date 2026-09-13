import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/repositories/onboarding_repository.dart';
import '../main_navigation_screen.dart';
import 'models/onboarding_models.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final bool isRevisit;

  const OnboardingScreen({
    super.key,
    this.isRevisit = false,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  final List<OnboardingPageData> _pages = OnboardingPageData.pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleFinish() async {
    HapticFeedback.mediumImpact();
    if (widget.isRevisit) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      await ref.read(onboardingCompletedProvider.notifier).completeOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
      );
    }
  }

  void _handleNext() {
    HapticFeedback.selectionClick();
    if (_currentPage < _pages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _handleFinish();
    }
  }

  void _handlePrevious() {
    HapticFeedback.selectionClick();
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = _pages[_currentPage].gradientColors.first;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar (Step Counter & Skip / Close button)
            _buildTopBar(context, isDark, activeColor),

            // PageView Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPageItem(context, _pages[index], isDark);
                },
              ),
            ),

            // Bottom Navigation Bar (Prev, Indicators, Next / Get Started)
            _buildBottomBar(context, isDark, activeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, Color activeColor) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.adaptiveMargin,
        context.isMediumOrWider ? 16 : 10,
        context.adaptiveMargin,
        8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Step Counter Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: activeColor.withValues(alpha: isDark ? 0.35 : 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Step ${_currentPage + 1} of ${_pages.length}',
                  style: TextStyle(
                    fontSize: context.adaptiveFontSize(12,
                        tabletSize: 14, largeTabletSize: 15),
                    fontWeight: FontWeight.bold,
                    color: activeColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // Action Button: Close (in revisit mode) or Skip (on first launch)
          if (widget.isRevisit)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close Guide',
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            )
          else if (_currentPage < _pages.length - 1)
            TextButton(
              onPressed: _handleFinish,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: context.adaptiveFontSize(13,
                          tabletSize: 15, largeTabletSize: 16),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.fast_forward_rounded,
                    size: context.adaptiveIconSize(16,
                        tabletSize: 18, largeTabletSize: 20),
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 48), // Empty placeholder to balance layout
        ],
      ),
    );
  }

  Widget _buildPageItem(
    BuildContext context,
    OnboardingPageData page,
    bool isDark,
  ) {
    final isTablet = context.isMediumOrWider;

    return AdaptivePageContainer(
      maxWidth: 1000,
      padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Hero Section (Header Icon, Tag, Title, Subtitle)
          _buildHeroHeader(context, page, isDark),

          const SizedBox(height: 16),

          // Feature Highlights List (Scrollable)
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.02, 0.96, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: isTablet
                  ? _buildFeaturesGrid(context, page.features, isDark)
                  : _buildFeaturesList(context, page.features, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(
    BuildContext context,
    OnboardingPageData page,
    bool isDark,
  ) {
    final gradient = LinearGradient(
      colors: page.gradientColors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final heroSize =
        context.isLargeTablet ? 72.0 : (context.isMediumOrWider ? 62.0 : 54.0);
    final iconSize =
        context.isLargeTablet ? 36.0 : (context.isMediumOrWider ? 32.0 : 28.0);

    return Column(
      children: [
        // Hero Icon Circle with Glow
        Container(
          width: heroSize,
          height: heroSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: page.gradientColors.first.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            page.heroIcon,
            size: iconSize,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),

        // Badge pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: page.gradientColors.first
                .withValues(alpha: isDark ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: page.gradientColors.first
                  .withValues(alpha: isDark ? 0.3 : 0.15),
              width: 0.8,
            ),
          ),
          child: Text(
            page.badge,
            style: TextStyle(
              fontSize: context.adaptiveFontSize(10.5,
                  tabletSize: 12, largeTabletSize: 13),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: page.gradientColors.first,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          page.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.adaptiveFontSize(22,
                tabletSize: 28, largeTabletSize: 32),
            fontWeight: FontWeight.w800,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.adaptiveFontSize(12.5,
                  tabletSize: 15, largeTabletSize: 16),
              height: 1.35,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesList(
    BuildContext context,
    List<OnboardingFeatureItem> features,
    bool isDark,
  ) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: features.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildFeatureCard(context, features[index], isDark);
      },
    );
  }

  Widget _buildFeaturesGrid(
    BuildContext context,
    List<OnboardingFeatureItem> features,
    bool isDark,
  ) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.isLargeTablet ? 3 : 2,
        childAspectRatio: context.isLargeTablet ? 2.4 : 2.6,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        return _buildFeatureCard(context, features[index], isDark);
      },
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    OnboardingFeatureItem feature,
    bool isDark,
  ) {
    final iconBoxSize =
        context.isLargeTablet ? 44.0 : (context.isMediumOrWider ? 40.0 : 36.0);
    final iconSize =
        context.isLargeTablet ? 22.0 : (context.isMediumOrWider ? 20.0 : 18.0);

    return Container(
      padding: EdgeInsets.all(
        context.isLargeTablet ? 14 : (context.isMediumOrWider ? 12 : 11),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading Feature Icon with subtle tinted background
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: feature.accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    feature.accentColor.withValues(alpha: isDark ? 0.35 : 0.2),
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              feature.icon,
              size: iconSize,
              color: feature.accentColor,
            ),
          ),
          const SizedBox(width: 12),

          // Title, Badge and Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        feature.title,
                        style: TextStyle(
                          fontSize: context.adaptiveFontSize(13,
                              tabletSize: 15, largeTabletSize: 16),
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (feature.badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: feature.accentColor
                              .withValues(alpha: isDark ? 0.22 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          feature.badge!,
                          style: TextStyle(
                            fontSize: context.adaptiveFontSize(9.5,
                                tabletSize: 11, largeTabletSize: 12),
                            fontWeight: FontWeight.bold,
                            color: feature.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  feature.description,
                  style: TextStyle(
                    fontSize: context.adaptiveFontSize(11.5,
                        tabletSize: 13, largeTabletSize: 14),
                    height: 1.3,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isDark, Color activeColor) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.adaptiveMargin,
        12,
        context.adaptiveMargin,
        context.isMediumOrWider ? 20 : 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 0.8,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous Arrow Button (or empty box)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _currentPage > 0 ? 1.0 : 0.0,
                child: IconButton.filledTonal(
                  onPressed: _currentPage > 0 ? _handlePrevious : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Previous',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.surfaceVariantDark
                        : AppColors.surfaceVariantLight,
                    foregroundColor: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),

              // Expanding Dot Indicators
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_pages.length, (index) {
                  final isSelected = index == _currentPage;
                  final dotColor = _pages[index].gradientColors.first;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isSelected ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? dotColor
                          : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),

              // Next / Get Started Action Button
              if (!isLastPage)
                FilledButton.icon(
                  onPressed: _handleNext,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Next'),
                  style: FilledButton.styleFrom(
                    backgroundColor: activeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: _pages.last.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _pages.last.gradientColors.first
                            .withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _handleFinish,
                    icon: Icon(
                      widget.isRevisit
                          ? Icons.check_circle_outline_rounded
                          : Icons.rocket_launch_rounded,
                      size: 18,
                    ),
                    label: Text(
                      widget.isRevisit ? 'Got It' : 'Get Started',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
