import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_enhanced.dart';

/// Enhanced App Card with gradient and shadow options
class EnhancedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? elevation;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Border? border;
  final List<Color>? gradientColors;
  final bool useGlass;
  final bool useGradient;

  const EnhancedCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.symmetric(vertical: 8),
    this.elevation,
    this.backgroundColor,
    this.borderRadius,
    this.onTap,
    this.border,
    this.gradientColors,
    this.useGlass = false,
    this.useGradient = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: _getDecoration(context),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(CoopvestRadius.card),
        child: Material(
          color: useGradient || useGlass ? Colors.transparent : backgroundColor,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius ?? BorderRadius.circular(CoopvestRadius.card),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(CoopvestSpacing.cardPadding),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _getDecoration(BuildContext context) {
    if (useGlass) {
      return GlassConfig.lightGlass();
    }

    if (useGradient && gradientColors != null) {
      return BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors!,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius ?? BorderRadius.circular(CoopvestRadius.card),
        border: border,
        boxShadow: CoopvestShadows.medium,
      );
    }

    return BoxDecoration(
      color: backgroundColor, // Will use Theme's card color if null
      borderRadius: borderRadius ?? BorderRadius.circular(CoopvestRadius.card),
      border: border,
      boxShadow: elevation != null
          ? [BoxShadow(color: CoopvestColorsEnhanced.shadowMedium, blurRadius: elevation! * 2)]
          : CoopvestShadows.medium,
    );
  }
}

/// Beautiful Stat Card with gradient background
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback? onTap;
  final String? subtitle;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradientColors,
    this.onTap,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EnhancedCard(
      useGradient: true,
      gradientColors: gradientColors,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(CoopvestRadius.medium),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: CoopvestTypography.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: CoopvestTypography.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: CoopvestTypography.bodySmall.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact Stat Card for grid layouts
class CompactStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const CompactStatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return EnhancedCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(CoopvestRadius.small),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: CoopvestTypography.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: CoopvestTypography.bodySmall.copyWith(
              color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Quick Action Button with icon and label
class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final List<Color>? gradientColors;
  final Color? iconColor;
  final double? iconSize;

  const QuickActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradientColors,
    this.iconColor,
    this.iconSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          gradient: gradientColors != null
              ? LinearGradient(
                  colors: gradientColors!,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: gradientColors == null ? (isDarkMode ? Colors.white10 : CoopvestColors.veryLightGray) : null,
          borderRadius: BorderRadius.circular(CoopvestRadius.large),
          boxShadow: gradientColors != null ? CoopvestShadows.coloredPrimary : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: gradientColors != null
                    ? Colors.white.withOpacity(0.2)
                    : CoopvestColorsEnhanced.primaryGradientStart.withOpacity(0.1),
                borderRadius: BorderRadius.circular(CoopvestRadius.medium),
              ),
              child: Icon(
                icon,
                color: gradientColors != null ? Colors.white : (iconColor ?? CoopvestColors.primary),
                size: iconSize ?? 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: CoopvestTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: gradientColors != null ? Colors.white : (isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Section Header with optional action
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final String? viewAllText;
  final List<Color>? titleGradient;

  const SectionHeader({
    Key? key,
    required this.title,
    this.onViewAll,
    this.viewAllText = 'View All',
    this.titleGradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        titleGradient != null
            ? ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: titleGradient!,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  title,
                  style: CoopvestTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              )
            : Text(
                title,
                style: CoopvestTypography.titleMedium.copyWith(
                  color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: Text(
              viewAllText!,
              style: CoopvestTypography.labelMedium.copyWith(
                color: CoopvestColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
