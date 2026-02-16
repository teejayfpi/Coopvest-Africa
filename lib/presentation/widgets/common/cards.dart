import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';

/// Standard Card Component
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double elevation;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Border? border;

  const AppCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(0),
    this.elevation = 2,
    this.backgroundColor,
    this.borderRadius,
    this.onTap,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Card(
        elevation: elevation,
        color: backgroundColor, // Use theme color if null
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          side: border?.top ?? BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Elevated Card Component
class ElevatedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const ElevatedCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(0),
    this.backgroundColor,
    this.borderRadius,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      margin: margin,
      elevation: 4,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      onTap: onTap,
      child: child,
    );
  }
}

/// Outlined Card Component
class OutlinedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;

  const OutlinedCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(0),
    this.backgroundColor,
    this.borderRadius,
    this.onTap,
    this.borderColor,
    this.borderWidth = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? Theme.of(context).dividerColor;
    
    return AppCard(
      padding: padding,
      margin: margin,
      elevation: 0,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      onTap: onTap,
      border: Border.all(
        color: effectiveBorderColor,
        width: borderWidth,
      ),
      child: child,
    );
  }
}

/// Balance Card Component
class BalanceCard extends StatelessWidget {
  final String title;
  final double amount;
  final String? subtitle;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const BalanceCard({
    Key? key,
    required this.title,
    required this.amount,
    this.subtitle,
    this.backgroundColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: CoopvestTypography.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₦${amount.toStringAsFixed(2).replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            )}',
            style: CoopvestTypography.displaySmall.copyWith(
              color: Colors.white,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: CoopvestTypography.bodySmall.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Transaction Card Component
class TransactionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final bool isIncome;
  final String date;
  final IconData icon;
  final Color? iconBackgroundColor;
  final VoidCallback? onTap;

  const TransactionCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    required this.date,
    required this.icon,
    this.iconBackgroundColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      onTap: onTap,
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBackgroundColor ?? (isDarkMode ? Colors.white10 : CoopvestColors.veryLightGray),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: CoopvestTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: CoopvestTypography.bodySmall.copyWith(
                    color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}₦${amount.toStringAsFixed(2)}',
                style: CoopvestTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isIncome ? CoopvestColors.success : CoopvestColors.error,
                ),
              ),
              Text(
                date,
                style: CoopvestTypography.bodySmall.copyWith(
                  color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Loan Card Component
class LoanCard extends StatelessWidget {
  final String loanId;
  final double amount;
  final String status;
  final double monthlyRepayment;
  final int tenure;
  final VoidCallback? onTap;

  const LoanCard({
    Key? key,
    required this.loanId,
    required this.amount,
    required this.status,
    required this.monthlyRepayment,
    required this.tenure,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(status);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Loan #$loanId',
                style: CoopvestTypography.headlineSmall,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((255 * 0.1).toInt()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: CoopvestTypography.labelSmall.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Amount
          Text(
            '₦${amount.toStringAsFixed(2).replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            )}',
            style: CoopvestTypography.headlineMedium,
          ),
          const SizedBox(height: 12),
          // Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Repayment',
                    style: CoopvestTypography.bodySmall.copyWith(
                      color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                    ),
                  ),
                  Text(
                    '₦${monthlyRepayment.toStringAsFixed(2)}',
                    style: CoopvestTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Tenure',
                    style: CoopvestTypography.bodySmall.copyWith(
                      color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                    ),
                  ),
                  Text(
                    '$tenure months',
                    style: CoopvestTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return CoopvestColors.success;
      case 'pending':
        return CoopvestColors.warning;
      case 'completed':
        return CoopvestColors.info;
      case 'rejected':
      case 'defaulted':
        return CoopvestColors.error;
      default:
        return CoopvestColors.mediumGray;
    }
  }
}
