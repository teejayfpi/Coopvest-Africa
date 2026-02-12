import 'package:flutter/material.dart';

/// Coopvest Enhanced Colors - Beautiful gradient and effect colors
class CoopvestColorsEnhanced {
  // Primary Gradient Colors
  static const Color primaryGradientStart = Color(0xFF1B5E20);
  static const Color primaryGradientEnd = Color(0xFF2E7D32);
  static const Color secondaryGradientStart = Color(0xFF4CAF50);
  static const Color secondaryGradientEnd = Color(0xFF81C784);

  // Accent Colors
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentPurple = Color(0xFF7C4DFF);
  static const Color accentTeal = Color(0xFF00BFA5);
  static const Color accentPink = Color(0xFFFF4081);

  // Gradient List for Primary
  static const List<Color> primaryGradient = [
    primaryGradientStart,
    primaryGradientEnd,
  ];

  static const List<Color> secondaryGradient = [
    secondaryGradientStart,
    secondaryGradientEnd,
  ];

  static const List<Color> successGradient = [
    Color(0xFF43A047),
    Color(0xFF66BB6A),
  ];

  static const List<Color> warningGradient = [
    Color(0xFFFF9800),
    Color(0xFFFFB74D),
  ];

  static const List<Color> errorGradient = [
    Color(0xFFE53935),
    Color(0xFFEF5350),
  ];

  static const List<Color> infoGradient = [
    Color(0xFF1E88E5),
    Color(0xFF42A5F5),
  ];

  // Accent Gradient
  static const List<Color> accentGradient = [
    Color(0xFFFF9800),
    Color(0xFFFF5722),
  ];

  static const List<Color> purpleGradient = [
    Color(0xFF7C4DFF),
    Color(0xFFB388FF),
  ];

  static const List<Color> tealGradient = [
    Color(0xFF00BFA5),
    Color(0xFF64FFDA),
  ];

  // Glassmorphism Colors
  static const Color glassWhite = Color(0xFFFFFFFF);
  static const Color glassWhiteLight = Color(0xFFF8F9FA);
  static const Color glassOverlay = Color(0xFFFFFFFF);

  // Background Gradients
  static const List<Color> backgroundGradientLight = [
    Color(0xFFF5F7FA),
    Color(0xFFE8ECEF),
  ];

  static const List<Color> backgroundGradientDark = [
    Color(0xFF121212),
    Color(0xFF1E1E1E),
  ];

  // Card Gradients
  static const List<Color> cardGradient1 = [
    Color(0xFF1B5E20),
    Color(0xFF2E7D32),
  ];

  static const List<Color> cardGradient2 = [
    Color(0xFF1565C0),
    Color(0xFF1976D2),
  ];

  static const List<Color> cardGradient3 = [
    Color(0xFF7B1FA2),
    Color(0xFF9C27B0),
  ];

  static const List<Color> cardGradient4 = [
    Color(0xFFE65100),
    Color(0xFFFF9800),
  ];

  // Shimmer Colors
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // Shadow Colors
  static const Color shadowSmall = Color(0x1A000000);
  static const Color shadowMedium = Color(0x26000000);
  static const Color shadowLarge = Color(0x33000000);

  // Overlay Colors
  static const Color overlayLight = Color(0x8AFFFFFF);
  static const Color overlayDark = Color(0x8A000000);

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF1B5E20),
    Color(0xFF4CAF50),
    Color(0xFF81C784),
    Color(0xFFA5D6A7),
    Color(0xFFC8E6C9),
    Color(0xFFE8F5E9),
  ];

  // Status Colors - More vibrant
  static const Color success = Color(0xFF43A047);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF1E88E5);
  static const Color infoLight = Color(0xFFE3F2FD);

  // Neutral Colors
  static const Color darkText = Color(0xFF212121);
  static const Color mediumText = Color(0xFF757575);
  static const Color lightText = Color(0xFFBDBDBD);
  static const Color disabled = Color(0xFFE0E0E0);
}

/// Coopvest Gradients Helper
class CoopvestGradients {
  // Primary button gradient
  static LinearGradient primaryButton = const LinearGradient(
    colors: CoopvestColorsEnhanced.primaryGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Secondary gradient
  static LinearGradient secondary = const LinearGradient(
    colors: CoopvestColorsEnhanced.secondaryGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Success gradient
  static LinearGradient success = const LinearGradient(
    colors: CoopvestColorsEnhanced.successGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Warning gradient
  static LinearGradient warning = const LinearGradient(
    colors: CoopvestColorsEnhanced.warningGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Error gradient
  static LinearGradient error = const LinearGradient(
    colors: CoopvestColorsEnhanced.errorGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Background gradient
  static LinearGradient background = const LinearGradient(
    colors: CoopvestColorsEnhanced.backgroundGradientLight,
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Card gradient 1
  static LinearGradient card1 = const LinearGradient(
    colors: CoopvestColorsEnhanced.cardGradient1,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card gradient 2
  static LinearGradient card2 = const LinearGradient(
    colors: CoopvestColorsEnhanced.cardGradient2,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card gradient 3
  static LinearGradient card3 = const LinearGradient(
    colors: CoopvestColorsEnhanced.cardGradient3,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card gradient 4
  static LinearGradient card4 = const LinearGradient(
    colors: CoopvestColorsEnhanced.cardGradient4,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text gradient
  static LinearGradient textGradient = const LinearGradient(
    colors: CoopvestColorsEnhanced.primaryGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Diagonal gradient
  static LinearGradient diagonal = const LinearGradient(
    colors: [
      Color(0xFF1B5E20),
      Color(0xFF4CAF50),
      Color(0xFF81C784),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Coopvest Shadows
class CoopvestShadows {
  // Small shadow
  static List<BoxShadow> small = [
    BoxShadow(
      color: CoopvestColorsEnhanced.shadowSmall,
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  // Medium shadow
  static List<BoxShadow> medium = [
    BoxShadow(
      color: CoopvestColorsEnhanced.shadowMedium,
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // Large shadow
  static List<BoxShadow> large = [
    BoxShadow(
      color: CoopvestColorsEnhanced.shadowLarge,
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // Inner shadow
  static List<BoxShadow> inner = [
    BoxShadow(
      color: CoopvestColorsEnhanced.shadowSmall,
      blurRadius: 2,
      offset: Offset(0, 2),
      spreadRadius: -1,
    ),
  ];

  // Colored shadow for cards
  static List<BoxShadow> coloredPrimary = [
    BoxShadow(
      color: CoopvestColorsEnhanced.primaryGradientStart.withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Glassmorphism Configuration
class GlassConfig {
  // Light glass
  static BoxDecoration lightGlass({
    double opacity = 0.15,
    double blur = 10,
  }) {
    return BoxDecoration(
      color: CoopvestColorsEnhanced.glassWhite.withOpacity(opacity),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: CoopvestColorsEnhanced.glassWhite.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: blur,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Dark glass
  static BoxDecoration darkGlass({
    double opacity = 0.2,
    double blur = 10,
  }) {
    return BoxDecoration(
      color: Colors.black.withOpacity(opacity),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: blur,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Gradient glass
  static BoxDecoration gradientGlass({
    required List<Color> colors,
    double opacity = 0.2,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors.map((c) => c.withOpacity(opacity)).toList(),
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
    );
  }
}

/// Animation Durations
class CoopvestAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);

  // Curves
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.easeOutBack;
  static const Curve springCurve = Curves.elasticOut;
}

/// Spacing Constants
class CoopvestSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Screen padding
  static const double screenPadding = 24.0;
  static const double screenPaddingSmall = 16.0;

  // Card padding
  static const double cardPadding = 20.0;
  static const double cardPaddingSmall = 16.0;
}

/// Border Radius
class CoopvestRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xlarge = 20.0;
  static const double circle = 50.0;

  // Button radius
  static const double button = small;
  static const double card = medium;
  static const double dialog = large;
}

/// Icon Sizes
class CoopvestIconSize {
  static const double small = 16.0;
  static const double medium = 24.0;
  static const double large = 32.0;
  static const double xlarge = 48.0;
  static const double xxlarge = 64.0;
}
