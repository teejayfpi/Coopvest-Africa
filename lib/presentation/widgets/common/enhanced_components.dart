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
    Widget card = Container(
      margin: margin,
      decoration: _getDecoration(),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(CoopvestRadius.card),
        child: Material(
          color: useGradient || useGlass ? Colors.transparent : backgroundColor ?? CoopvestColors.white,
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

    return card;
  }

  BoxDecoration _getDecoration() {
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
      color: backgroundColor ?? CoopvestColors.white,
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
              color: CoopvestColors.mediumGray,
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
          color: gradientColors == null ? CoopvestColors.veryLightGray : null,
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
                color: gradientColors != null ? Colors.white : CoopvestColors.darkGray,
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
                  ),
                ),
              )
            : Text(
                title,
                style: CoopvestTypography.titleMedium.copyWith(
                  color: CoopvestColors.darkGray,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: Text(
              viewAllText!,
              style: CoopvestTypography.labelLarge.copyWith(
                color: CoopvestColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Progress Card for goals and savings
class ProgressCard extends StatelessWidget {
  final String title;
  final double progress;
  final String currentAmount;
  final String targetAmount;
  final String? subtitle;
  final VoidCallback? onTap;
  final List<Color> gradientColors;

  const ProgressCard({
    Key? key,
    required this.title,
    required this.progress,
    required this.currentAmount,
    required this.targetAmount,
    this.subtitle,
    this.onTap,
    this.gradientColors = CoopvestColorsEnhanced.primaryGradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EnhancedCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: CoopvestTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '\${(progress * 100).toStringAsFixed(0)}%',
                  style: CoopvestTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 10,
              backgroundColor: CoopvestColors.veryLightGray,
              valueColor: AlwaysStoppedAnimation<Color>(
                gradientColors.first,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentAmount,
                style: CoopvestTypography.bodyMedium.copyWith(
                  color: CoopvestColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'of \$targetAmount',
                style: CoopvestTypography.bodySmall.copyWith(
                  color: CoopvestColors.mediumGray,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 14,
                  color: CoopvestColors.mediumGray,
                ),
                const SizedBox(width: 4),
                Text(
                  subtitle!,
                  style: CoopvestTypography.bodySmall.copyWith(
                    color: CoopvestColors.mediumGray,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Info Row for displaying key-value pairs
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool showArrow;

  const InfoRow({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.onTap,
    this.showArrow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? CoopvestColors.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(CoopvestRadius.small),
              ),
              child: Icon(
                icon,
                color: iconColor ?? CoopvestColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: CoopvestTypography.bodySmall.copyWith(
                      color: CoopvestColors.mediumGray,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: CoopvestTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow)
              Icon(
                Icons.chevron_right,
                color: CoopvestColors.mediumGray,
              ),
          ],
        ),
      ),
    );
  }
}

/// Status Badge with gradient
class StatusBadge extends StatelessWidget {
  final String text;
  final List<Color> gradientColors;
  final TextStyle? textStyle;

  const StatusBadge({
    Key? key,
    required this.text,
    this.gradientColors = CoopvestColorsEnhanced.successGradient,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text.toUpperCase(),
        style: textStyle ??
            CoopvestTypography.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

/// Activity Item with icon and styling
class ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final bool isIncome;
  final String date;
  final VoidCallback? onTap;

  const ActivityItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    required this.date,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? CoopvestColors.success : CoopvestColors.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(CoopvestRadius.medium),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: CoopvestTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: CoopvestTypography.bodySmall.copyWith(
                      color: CoopvestColors.mediumGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\${isIncome ? '+' : '-'}N\$amount',
                  style: CoopvestTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: CoopvestTypography.bodySmall.copyWith(
                    color: CoopvestColors.mediumGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
