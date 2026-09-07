import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Centralized design tokens for corner radii across the app.
/// Implements mathematically concentric corner radii: R_inner = max(minRadius, R_outer - padding)
class AppRadii {
  AppRadii._();

  // --- Base Outer Radii ---
  /// Bottom sheets top corners (Material 3 standard)
  static const double sheet = 24.0;

  /// Full-screen modals, dialogs, and alert boxes
  static const double dialog = 20.0;

  /// Large hero cards and prominent feature cards
  static const double cardLarge = 18.0;

  /// Standard content cards, panels, and containers
  static const double card = 16.0;

  /// Compact cards, list tiles, and secondary containers
  static const double cardSmall = 12.0;

  // --- Concentric Inner Radii ---
  /// Inner content container within a standard card (e.g. 16px card with 6px padding)
  static const double cardInner = 10.0;

  /// Inner thumbnail or icon box within a small card (e.g. 12px card with 4px padding)
  static const double cardInnerSmall = 8.0;

  /// Tags, chips, format badges, and small status pills
  static const double badge = 6.0;

  /// Micro indicators, progress bars, and tiny dots
  static const double micro = 4.0;

  /// Stadium / capsule / pill buttons
  static const double pill = 999.0;

  // --- Concentric Math Helpers ---
  /// Calculates the mathematically concentric inner radius for a nested shape.
  /// Formula: R_inner = max(minRadius, R_outer - padding)
  static double concentric(
    double outerRadius, {
    required double padding,
    double minRadius = 4.0,
  }) {
    final inner = outerRadius - padding;
    return math.max(minRadius, inner);
  }

  /// Calculates concentric BorderRadius for an inner container.
  static BorderRadius concentricBorderRadius(
    double outerRadius, {
    required double padding,
    double minRadius = 4.0,
  }) {
    return BorderRadius.circular(
      concentric(outerRadius, padding: padding, minRadius: minRadius),
    );
  }

  // --- Pre-built BorderRadius Objects ---
  static const BorderRadius sheetRadius = BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius dialogRadius = BorderRadius.all(Radius.circular(dialog));
  static const BorderRadius cardLargeRadius = BorderRadius.all(Radius.circular(cardLarge));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius cardInnerRadius = BorderRadius.all(Radius.circular(cardInner));
  static const BorderRadius cardSmallRadius = BorderRadius.all(Radius.circular(cardSmall));
  static const BorderRadius cardInnerSmallRadius = BorderRadius.all(Radius.circular(cardInnerSmall));
  static const BorderRadius badgeRadius = BorderRadius.all(Radius.circular(badge));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
}
