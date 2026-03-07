import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

/// Theme-aware color extension for screens
/// Provides adaptive colors that work in both light and dark mode
extension ScreenTheme on BuildContext {
  /// Main scaffold background color
  Color get scaffoldBackground =>
      Theme.of(this).brightness == Brightness.dark
          ? CoopvestColors.darkBackground
          : CoopvestColors.white;

  /// Card background color (lighter than scaffold)
  Color get cardBackground =>
      Theme.of(this).brightness == Brightness.dark
          ? CoopvestColors.darkSurface
          : CoopvestColors.white;

  /// Secondary card background (for nested cards)
  Color get secondaryCardBackground =>
      Theme.of(this).brightness == Brightness.dark
          ? CoopvestColors.darkSurface.withOpacity(0.8)
          : CoopvestColors.veryLightGray;

  /// Text color for primary content
  Color get textPrimary =>
      Theme.of(this).brightness == Brightness.dark
          ? CoopvestColors.darkText
          : CoopvestColors.textPrimary;

  /// Text color for secondary content
  Color get textSecondary =>
      Theme.of(this).brightness == Brightness.dark
          ? CoopvestColors.darkTextSecondary
          : CoopvestColors.textSecondary;

  /// Divider color
  Color get dividerColor =>
      Theme.of(this).brightness == Brightness.dark
          ? CoopvestColors.darkDivider
          : CoopvestColors.lightGray;

  /// Icon color for primary icons
  Color get iconPrimary =>
      Theme.of(this).brightness == Brightness.dark
          ? CoopvestColors.darkText
          : CoopvestColors.darkGray;

  /// Icon color for secondary icons
  Color get iconSecondary =>
      Theme.of(this).brightness == Brightness.dark
          ? CoopvestColors.darkTextSecondary
          : CoopvestColors.mediumGray;

  /// Primary button text color
  Color get buttonTextPrimary => Colors.white;

  /// Input field background
  Color get inputBackground =>
      Theme.of(this).brightness == Brightness.dark
          ? CoopvestColors.darkSurface
          : CoopvestColors.veryLightGray;

  /// Status badge background
  Color get statusBadgeBackground =>
      Theme.of(this).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.1)
          : CoopvestColors.veryLightGray;

  /// Gradient overlay for cards
  List<Color> get cardGradient => Theme.of(this).brightness == Brightness.dark
      ? [
          CoopvestColors.darkSurface,
          CoopvestColors.darkSurface.withOpacity(0.9),
        ]
      : [
          CoopvestColors.white,
          CoopvestColors.white.withOpacity(0.9),
        ];
}

/// Helper function to get theme-aware colors
class AppColors {
  /// Get scaffold background color based on theme
  static Color scaffoldBackground(BuildContext context) =>
      context.scaffoldBackground;

  /// Get card background color based on theme
  static Color cardBackground(BuildContext context) =>
      context.cardBackground;

  /// Get primary text color based on theme
  static Color textPrimary(BuildContext context) => context.textPrimary;

  /// Get secondary text color based on theme
  static Color textSecondary(BuildContext context) => context.textSecondary;

  /// Get divider color based on theme
  static Color dividerColor(BuildContext context) => context.dividerColor;

  /// Get icon color based on theme
  static Color iconPrimary(BuildContext context) => context.iconPrimary;

  /// Get input background color based on theme
  static Color inputBackground(BuildContext context) => context.inputBackground;

  /// Check if dark mode is enabled
  static bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
