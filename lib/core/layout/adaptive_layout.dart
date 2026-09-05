import 'package:flutter/material.dart';

/// Material 3 Window Size Classes based on width breakpoints.
/// Reference: https://m3.material.io/foundations/layout/applying-layout/window-size-classes
enum WindowSizeClass {
  /// Phones in portrait (< 600dp)
  compact,

  /// Tablets in portrait, foldables unfolded (600dp – 839dp)
  medium,

  /// Tablets in landscape, laptops, small desktop windows (840dp – 1199dp)
  expanded,

  /// Desktop monitors (1200dp – 1599dp)
  large,

  /// Ultra-wide desktop screens (≥ 1600dp)
  extraLarge,
}

/// Standard Material 3 layout constants and breakpoints.
class M3Breakpoints {
  const M3Breakpoints._();

  static const double compactMaxWidth = 600.0;
  static const double mediumMaxWidth = 840.0;
  static const double expandedMaxWidth = 1200.0;
  static const double largeMaxWidth = 1600.0;

  /// Standard recommended maximum content width for readability on ultra-wide screens.
  static const double maxContentWidth = 1200.0;

  /// Standard M3 margins
  static const double marginCompact = 16.0;
  static const double marginMedium = 24.0;
  static const double marginExpanded = 24.0;
  static const double marginLarge = 32.0;
}

/// Responsive extensions on [BuildContext] for Material 3 layouts.
extension AdaptiveLayoutExtension on BuildContext {
  /// Screen size of current context.
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Screen width of current context.
  double get screenWidth => screenSize.width;

  /// Screen height of current context.
  double get screenHeight => screenSize.height;

  /// Material 3 Window Size Class calculated from current width.
  WindowSizeClass get windowSizeClass {
    final width = screenWidth;
    if (width < M3Breakpoints.compactMaxWidth) {
      return WindowSizeClass.compact;
    } else if (width < M3Breakpoints.mediumMaxWidth) {
      return WindowSizeClass.medium;
    } else if (width < M3Breakpoints.expandedMaxWidth) {
      return WindowSizeClass.expanded;
    } else if (width < M3Breakpoints.largeMaxWidth) {
      return WindowSizeClass.large;
    } else {
      return WindowSizeClass.extraLarge;
    }
  }

  /// Whether current layout is Compact (< 600dp).
  bool get isCompact => windowSizeClass == WindowSizeClass.compact;

  /// Whether current layout is Medium (600dp – 839dp).
  bool get isMedium => windowSizeClass == WindowSizeClass.medium;

  /// Whether current layout is Expanded (840dp – 1199dp).
  bool get isExpanded => windowSizeClass == WindowSizeClass.expanded;

  /// Whether current layout is Large (1200dp – 1599dp).
  bool get isLarge => windowSizeClass == WindowSizeClass.large;

  /// Whether current layout is Extra Large (≥ 1600dp).
  bool get isExtraLarge => windowSizeClass == WindowSizeClass.extraLarge;

  /// Whether current layout is Medium or wider (≥ 600dp), suitable for dual-pane layouts.
  bool get isMediumOrWider => screenWidth >= M3Breakpoints.compactMaxWidth;

  /// Whether current layout is Expanded or wider (≥ 840dp).
  bool get isExpandedOrWider => screenWidth >= M3Breakpoints.mediumMaxWidth;

  /// Returns a responsive value depending on the active Window Size Class.
  T responsiveValue<T>({
    required T compact,
    T? medium,
    T? expanded,
    T? large,
    T? extraLarge,
  }) {
    switch (windowSizeClass) {
      case WindowSizeClass.compact:
        return compact;
      case WindowSizeClass.medium:
        return medium ?? compact;
      case WindowSizeClass.expanded:
        return expanded ?? medium ?? compact;
      case WindowSizeClass.large:
        return large ?? expanded ?? medium ?? compact;
      case WindowSizeClass.extraLarge:
        return extraLarge ?? large ?? expanded ?? medium ?? compact;
    }
  }

  /// Standard Material 3 outer margin for content.
  double get adaptiveMargin => responsiveValue<double>(
        compact: M3Breakpoints.marginCompact,
        medium: M3Breakpoints.marginMedium,
        expanded: M3Breakpoints.marginExpanded,
        large: M3Breakpoints.marginLarge,
      );

  /// Standard grid column count for card grids.
  int get adaptiveGridColumns => responsiveValue<int>(
        compact: 2,
        medium: 3,
        expanded: 4,
        large: 5,
      );
}

/// A container that applies Material 3 margins and centers content
/// within a constrained maximum width on large/ultra-wide screens.
class AdaptivePageContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const AdaptivePageContainer({
    super.key,
    required this.child,
    this.maxWidth = M3Breakpoints.maxContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: context.adaptiveMargin,
        );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}

/// Material 3 Canonical Supporting Pane Layout.
///
/// Automatically switches between:
/// - Single-column stacked layout on Compact (< 600dp / [breakpoint]) screens.
/// - Side-by-side dual pane layout on Medium / Expanded (≥ [breakpoint]) screens.
class AdaptiveSupportingPane extends StatelessWidget {
  /// The primary focus pane (e.g. image preview canvas).
  final Widget primaryPane;

  /// The supporting pane containing secondary or contextual controls (e.g. editing tools).
  final Widget supportingPane;

  /// Optional action widget displayed at the bottom of the screen on Compact layouts,
  /// or embedded in the supporting pane on wider layouts.
  final Widget? bottomAction;

  /// Breakpoint width at which layout transitions to side-by-side (defaults to 600dp).
  final double breakpoint;

  /// Flex factor for primary pane in side-by-side mode (default: 5).
  final int primaryFlex;

  /// Flex factor for supporting pane in side-by-side mode (default: 5).
  final int supportingFlex;

  /// Spacing between panes in side-by-side mode (default: 20dp).
  final double paneSpacing;

  /// Padding around the overall layout in side-by-side mode.
  final EdgeInsetsGeometry? widePadding;

  /// Whether the primary pane should stretch to fill the viewport height in side-by-side mode (default: true).
  final bool stretchPrimaryPane;

  /// Whether the primary pane should be scrollable in side-by-side mode when not stretched (default: false).
  final bool scrollablePrimaryPane;

  /// Whether the supporting pane should be scrollable in side-by-side mode (default: true).
  final bool scrollableSupportingPane;

  const AdaptiveSupportingPane({
    super.key,
    required this.primaryPane,
    required this.supportingPane,
    this.bottomAction,
    this.breakpoint = M3Breakpoints.compactMaxWidth,
    this.primaryFlex = 5,
    this.supportingFlex = 5,
    this.paneSpacing = 20.0,
    this.widePadding,
    this.scrollablePrimaryPane = false,
    this.scrollableSupportingPane = true,
    this.stretchPrimaryPane = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= breakpoint;

        if (isWide) {
          // Dual-pane side-by-side layout (Material 3 Supporting Pane)
          final padding = widePadding ??
              EdgeInsets.symmetric(
                horizontal: context.adaptiveMargin,
                vertical: 16.0,
              );

          final effectivePrimary = stretchPrimaryPane
              ? primaryPane
              : (scrollablePrimaryPane
                  ? SingleChildScrollView(child: primaryPane)
                  : primaryPane);

          return Padding(
            padding: padding,
            child: Row(
              crossAxisAlignment: stretchPrimaryPane
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
              children: [
                // Primary Canvas Pane
                Expanded(
                  flex: primaryFlex,
                  child: effectivePrimary,
                ),
                SizedBox(width: paneSpacing),
                // Supporting Controls Pane
                Expanded(
                  flex: supportingFlex,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        supportingPane,
                        if (bottomAction != null) ...[
                          const SizedBox(height: 16),
                          bottomAction!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Single-column stacked layout (Compact / Mobile)
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.adaptiveMargin,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    primaryPane,
                    const SizedBox(height: 16),
                    supportingPane,
                  ],
                ),
              ),
            ),
            ?bottomAction,
          ],
        );
      },
    );
  }
}
