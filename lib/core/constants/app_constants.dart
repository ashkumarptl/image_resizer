class AppConstants {
  AppConstants._();

  static const String appName = 'Image Tools';
  static const String appTagline = 'Fast, Offline & Privacy-First Optimizer';
  static const String privacyPolicyUrl =
      'https://boom-libra-784.notion.site/Privacy-Policy-Image-Tools-3cf9d8fc428880c2bfa2e0fb1f6ba023?source=copy_link';

  // Quality Defaults
  static const int defaultQuality = 85;
  static const int minQuality = 10;
  static const int maxQuality = 100;

  // Target Size Presets in KB
  static const List<int> defaultTargetSizesKB = [20, 50, 100, 200, 500];

  // Percentage Resize Presets
  static const List<int> defaultPercentagePresets = [25, 50, 75];

  // Aspect Ratio Presets
  static const double aspectRatioSquare = 1.0;
  static const double aspectRatioPortrait = 3.0 / 4.0;
  static const double aspectRatioLandscape = 4.0 / 3.0;
  static const double aspectRatioWide = 16.0 / 9.0;
  static const double aspectRatioPassport = 3.5 / 4.5;

  // Supported Extensions
  static const List<String> supportedInputExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
    'gif',
  ];

  static const List<String> supportedOutputFormats = [
    'jpg',
    'png',
    'webp',
  ];

  // Max history items
  static const int maxHistoryItems = 30;

  // Guest Free Usage Limits
  static const int maxFreeGuestUses = 3;
}
