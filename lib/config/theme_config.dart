import 'package:flutter/material.dart';

/// Coopvest Color Palette
class CoopvestColors {
  // Primary Colors
  static const Color primary = Color(0xFF1B5E20); // Coopvest Green
  static const Color primaryLight = Color(0xFF2E7D32); // Lighter Green
  static const Color primaryDark = Color(0xFF1B5E20); // Darker Green
  static const Color secondary = Color(0xFF2E7D32);
  static const Color tertiary = Color(0xFF558B2F);

  // Neutral Colors
  static const Color black = Color(0xFF000000);
  static const Color darkGray = Color(0xFF212121);
  static const Color mediumGray = Color(0xFF757575);
  static const Color lightGray = Color(0xFFE0E0E0);
  static const Color veryLightGray = Color(0xFFF5F5F5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);

  // Semantic Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF1565C0);
  static const Color infoLight = Color(0xFFE3F2FD);
  static const Color scaffoldBackground = Color(0xFFFFFFFF);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkDivider = Color(0xFF424242);
}

/// Coopvest Typography
class CoopvestTypography {
  static const String fontFamily = 'Inter';

  // Display Styles
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.29,
    letterSpacing: 0,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.33,
    letterSpacing: 0,
  );

  // Headline Styles
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: 0.15,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.44,
    letterSpacing: 0.15,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.15,
  );

  // Title Styles
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18, 
    fontWeight: FontWeight.w700
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14, 
    fontWeight: FontWeight.w600
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12, 
    fontWeight: FontWeight.w500
  );

  // Body Styles
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
    letterSpacing: 0.25,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33,
    letterSpacing: 0.4,
  );

  // Label Styles
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.43,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.33,
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: 0.5,
  );
}

/// Coopvest Theme Data
class CoopvestTheme {
  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: CoopvestColors.primary,
    scaffoldBackgroundColor: CoopvestColors.white,
    colorScheme: const ColorScheme.light(
      primary: CoopvestColors.primary,
      secondary: CoopvestColors.secondary,
      tertiary: CoopvestColors.tertiary,
      surface: CoopvestColors.veryLightGray,
      error: CoopvestColors.error,
      onPrimary: CoopvestColors.white,
      onSecondary: CoopvestColors.white,
      onSurface: CoopvestColors.darkGray,
      onError: CoopvestColors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CoopvestColors.white,
      foregroundColor: CoopvestColors.darkGray,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: CoopvestTypography.headlineLarge,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: CoopvestColors.white,
      selectedItemColor: CoopvestColors.primary,
      unselectedItemColor: CoopvestColors.mediumGray,
      elevation: 8,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CoopvestColors.primary,
        foregroundColor: CoopvestColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: CoopvestTypography.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CoopvestColors.primary,
        side: const BorderSide(color: CoopvestColors.lightGray),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: CoopvestTypography.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CoopvestColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: CoopvestTypography.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CoopvestColors.veryLightGray,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CoopvestColors.lightGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CoopvestColors.lightGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CoopvestColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CoopvestColors.error),
      ),
      labelStyle: CoopvestTypography.bodyMedium.copyWith(
        color: CoopvestColors.mediumGray,
      ),
      hintStyle: CoopvestTypography.bodyMedium.copyWith(
        color: CoopvestColors.mediumGray,
      ),
    ),
    cardTheme: CardThemeData(
      color: CoopvestColors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(0),
    ),
    dividerTheme: const DividerThemeData(
      color: CoopvestColors.lightGray,
      thickness: 1,
      space: 16,
    ),
    textTheme: const TextTheme(
      displayLarge: CoopvestTypography.displayLarge,
      displayMedium: CoopvestTypography.displayMedium,
      displaySmall: CoopvestTypography.displaySmall,
      headlineLarge: CoopvestTypography.headlineLarge,
      headlineMedium: CoopvestTypography.headlineMedium,
      headlineSmall: CoopvestTypography.headlineSmall,
      bodyLarge: CoopvestTypography.bodyLarge,
      bodyMedium: CoopvestTypography.bodyMedium,
      bodySmall: CoopvestTypography.bodySmall,
      labelLarge: CoopvestTypography.labelLarge,
      labelMedium: CoopvestTypography.labelMedium,
      labelSmall: CoopvestTypography.labelSmall,
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: CoopvestColors.primary,
    scaffoldBackgroundColor: CoopvestColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4CAF50),
      secondary: Color(0xFF66BB6A),
      tertiary: Color(0xFF81C784),
      surface: CoopvestColors.darkSurface,
      error: CoopvestColors.error,
      onPrimary: CoopvestColors.darkBackground,
      onSecondary: CoopvestColors.darkBackground,
      onSurface: CoopvestColors.darkText,
      onError: CoopvestColors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CoopvestColors.darkSurface,
      foregroundColor: CoopvestColors.darkText,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: CoopvestTypography.headlineLarge,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: CoopvestColors.darkSurface,
      selectedItemColor: Color(0xFF4CAF50),
      unselectedItemColor: CoopvestColors.darkTextSecondary,
      elevation: 8,
    ),
    cardTheme: CardThemeData(
      color: CoopvestColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(0),
    ),
  );
}
