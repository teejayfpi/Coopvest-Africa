import 'package:flutter/material.dart';

/// Coopvest Color Palette
class CoopvestColors {
  // ───────────────────────────────────────────────────────────────────────────
  // Brand palette — emerald + gold fintech system.
  //
  // These are the single source of truth; screens should reference the token
  // rather than pasting a hex literal. The palette is a flat, two-colour brand
  // (emerald primary, gold accent) with gold reserved for ONE primary action
  // per screen so nothing competes with it.
  //
  // Every foreground/background pair below is checked against WCAG AA:
  // normal text >= 4.5:1, large text and UI boundaries >= 3:1. Three values
  // from the original brief were adjusted because they failed that bar — see
  // the notes on `textHint`, `success`/`pending` and the tinted pills.
  // ───────────────────────────────────────────────────────────────────────────

  // Primary — the original Coopvest green. Header, links, active nav, focus.
  // `primaryLight` is a lighter green used for accents and savings; it must NOT
  // be used as a header background, because the header label/nudge tokens only
  // reach 3.86:1 / 3.57:1 on it (they pass at 5.93:1 / 5.48:1 on `primary`).
  static const Color primary = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF2E7D32); // Savings tint
  static const Color primaryDark = Color(0xFF0F3D14);
  static const Color secondary = Color(0xFF2E7D32);
  static const Color tertiary = Color(0xFF16A34A);

  // Accent — gold. Exactly one primary action per screen uses `accent`.
  // `onAccent` is dark by design: white on gold is only 1.82:1, so gold
  // buttons must never use white text.
  static const Color accent = Color(0xFFF2B705);
  static const Color onAccent = Color(0xFF3D2E00); // 7.27:1 on accent
  static const Color accentPressed = Color(0xFFDBA400);
  static const Color accentIcon = Color(0xFF8A6300); // gold text/icon on white: 5.43:1

  // Surfaces
  static const Color pageBackground = Color(0xFFF5F7F6);
  static const Color cardBorder = Color(0xFFE3EAE6);

  // Icon chips — only the tint changes between cards.
  static const Color iconTintGreen = Color(0xFFE3F1EB);
  static const Color iconTintMint = Color(0xFFDDF3EA);
  static const Color iconTintGold = Color(0xFFFFF1C2);

  // Header
  static const Color headerDivider = Color(0xFF2F7F68);
  static const Color headerOutline = Color(0xFF6FB39D); // secondary button border, 3.23:1
  static const Color headerChip = Color(0xFF1F7A62);
  static const Color headerLabel = Color(0xFFCDE5DB); // 5.93:1 on primary
  static const Color headerNudge = Color(0xFFF5D56B); // 5.48:1 on primary

  // Neutral Colors
  static const Color black = Color(0xFF000000);
  static const Color darkGray = Color(0xFF101B16);
  static const Color mediumGray = Color(0xFF5C6B64);
  static const Color lightGray = Color(0xFFE3EAE6);
  static const Color veryLightGray = Color(0xFFF5F7F6);
  static const Color white = Color(0xFFFFFFFF);

  // Text. `textPrimary` and `textSecondary` are the body pair; `textHint` is
  // deliberately darker than the brief's #8A9891, which measured only 3.01:1
  // on a card and 2.80:1 on the page background — both below AA for normal
  // text. #66756D measures 4.85:1 / 4.51:1.
  static const Color textPrimary = Color(0xFF101B16);
  static const Color textSecondary = Color(0xFF5C6B64);
  static const Color textHint = Color(0xFF66756D);

  // Semantic Colors.
  //
  // NOTE: these are the *fill / icon* values. Text on white uses the darker
  // `*Text` variants below, because #16A34A (3.30:1) and #D97706 (3.19:1)
  // both fail AA as body text. Pills pair a #DCFCE7/#FEF3C7/#FEE2E2 wash with
  // the dark variant, and status is always paired with an icon or label so
  // colour is never the only signal.
  static const Color success = Color(0xFF16A34A);
  static const Color successText = Color(0xFF15803D); // 5.02:1 on white
  static const Color successSurface = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color pendingText = Color(0xFFB45309); // 5.02:1 on white
  static const Color pendingSurface = Color(0xFFFEF3C7);
  static const Color warningLight = Color(0xFFFFF1C2);
  static const Color error = Color(0xFFDC2626);
  static const Color errorText = Color(0xFFB91C1C); // 6.47:1 on white
  static const Color errorSurface = Color(0xFFFEE2E2);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF1565C0);
  static const Color infoLight = Color(0xFFE3F2FD);
  static const Color scaffoldBackground = Color(0xFFF5F7F6);

  // Dark Mode Colors
  // ── Dark palette ─────────────────────────────────────────────────────────
  // Dark is a real, member-selectable theme (light is the default). These use
  // a slightly green-tinted near-black rather than pure grey so dark still
  // reads as the Coopvest brand, and the greens are lifted because the light
  // brand green is far too dark to read on a dark surface.
  //
  // Contrast on #121714: darkText 16.3:1, darkTextSecondary 7.6:1,
  // darkPrimary 7.1:1 — all comfortably past AA.
  static const Color darkBackground = Color(0xFF0F1311);
  static const Color darkSurface = Color(0xFF1A211D);
  static const Color darkSurfaceElevated = Color(0xFF222B26);
  static const Color darkText = Color(0xFFF2F5F3);
  static const Color darkTextSecondary = Color(0xFFA9B5AF);
  static const Color darkDivider = Color(0xFF2E3934);
  // Lifted brand green for use ON dark surfaces (icons, links, active nav).
  static const Color darkPrimary = Color(0xFF6FCF87);
  // Gold needs no lift; it already passes on dark.
  static const Color darkAccent = Color(0xFFF2B705);
}

/// Coopvest shape and spacing tokens.
///
/// One radius family for the whole app: cards 16, buttons 12, icon chips 10,
/// quick-action circles. Spacing is always a multiple of 4/8 so the vertical
/// rhythm is identical between cards.
class CoopvestShape {
  static const double cardRadius = 16;
  static const double buttonRadius = 12;
  static const double chipRadius = 10;
  static const double headerRadius = 24;

  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 12;
  static const double gapLg = 16;
  static const double gapXl = 24;

  /// Minimum interactive size. Anything tappable must be at least this, per
  /// the accessibility requirement, even when the visual is smaller.
  static const double minTouchTarget = 44;

  /// Card treatment, shared by every card so nothing drifts: white fill, thin
  /// border, flat (no shadow). Depth comes from the border, not elevation.
  static BoxDecoration cardDecoration(BuildContext context) => BoxDecoration(
        color: CoopvestColors.white,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: CoopvestColors.cardBorder),
      );

  /// Tinted icon chip. Only the tint varies between cards.
  static BoxDecoration iconChip(Color tint, {bool circular = false}) =>
      BoxDecoration(
        color: tint,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(chipRadius),
      );
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
    scaffoldBackgroundColor: CoopvestColors.pageBackground,
    colorScheme: const ColorScheme.light(
      primary: CoopvestColors.primary,
      secondary: CoopvestColors.secondary,
      tertiary: CoopvestColors.tertiary,
      surface: CoopvestColors.pageBackground,
      outline: CoopvestColors.cardBorder,
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
      scrolledUnderElevation: 0,
      titleTextStyle: CoopvestTypography.headlineLarge,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: CoopvestColors.white,
      selectedItemColor: CoopvestColors.primary,
      unselectedItemColor: CoopvestColors.textHint,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CoopvestColors.primary,
        foregroundColor: CoopvestColors.white,
        minimumSize: const Size(0, CoopvestShape.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoopvestShape.buttonRadius),
        ),
        textStyle: CoopvestTypography.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CoopvestColors.primary,
        side: const BorderSide(color: CoopvestColors.cardBorder),
        minimumSize: const Size(0, CoopvestShape.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoopvestShape.buttonRadius),
        ),
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
    cardTheme: const CardThemeData(
      color: CoopvestColors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      margin: EdgeInsets.all(0),
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
      primary: CoopvestColors.darkPrimary,
      secondary: CoopvestColors.darkPrimary,
      tertiary: CoopvestColors.darkAccent,
      surface: CoopvestColors.darkSurface,
      outline: CoopvestColors.darkDivider,
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
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: CoopvestColors.darkBackground,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: CoopvestTypography.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF4CAF50),
        side: const BorderSide(color: CoopvestColors.darkDivider),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: CoopvestTypography.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF4CAF50),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: CoopvestTypography.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CoopvestColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CoopvestColors.darkDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CoopvestColors.darkDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: CoopvestColors.error),
      ),
      labelStyle: CoopvestTypography.bodyMedium.copyWith(
        color: CoopvestColors.darkTextSecondary,
      ),
      hintStyle: CoopvestTypography.bodyMedium.copyWith(
        color: CoopvestColors.darkTextSecondary,
      ),
    ),
    cardTheme: const CardThemeData(
      color: CoopvestColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      margin: EdgeInsets.all(0),
    ),
    dividerTheme: const DividerThemeData(
      color: CoopvestColors.darkDivider,
      thickness: 1,
      space: 16,
    ),
    textTheme: TextTheme(
      displayLarge: CoopvestTypography.displayLarge.copyWith(color: CoopvestColors.darkText),
      displayMedium: CoopvestTypography.displayMedium.copyWith(color: CoopvestColors.darkText),
      displaySmall: CoopvestTypography.displaySmall.copyWith(color: CoopvestColors.darkText),
      headlineLarge: CoopvestTypography.headlineLarge.copyWith(color: CoopvestColors.darkText),
      headlineMedium: CoopvestTypography.headlineMedium.copyWith(color: CoopvestColors.darkText),
      headlineSmall: CoopvestTypography.headlineSmall.copyWith(color: CoopvestColors.darkText),
      bodyLarge: CoopvestTypography.bodyLarge.copyWith(color: CoopvestColors.darkText),
      bodyMedium: CoopvestTypography.bodyMedium.copyWith(color: CoopvestColors.darkText),
      bodySmall: CoopvestTypography.bodySmall.copyWith(color: CoopvestColors.darkTextSecondary),
      labelLarge: CoopvestTypography.labelLarge.copyWith(color: CoopvestColors.darkText),
      labelMedium: CoopvestTypography.labelMedium.copyWith(color: CoopvestColors.darkText),
      labelSmall: CoopvestTypography.labelSmall.copyWith(color: CoopvestColors.darkTextSecondary),
    ),
  );
}
