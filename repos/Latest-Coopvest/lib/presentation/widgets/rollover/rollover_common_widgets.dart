import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../data/models/rollover_models.dart';

/// Rollover Status Badge Widget
class RolloverStatusBadge extends StatelessWidget {
  final RolloverStatus status;
  final bool isCompact;

  const RolloverStatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label) = _getStatusConfig();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.1).toInt()),
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        border: Border.all(color: color.withAlpha((255 * 0.3).toInt())),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: isCompact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, String) _getStatusConfig() {
    switch (status) {
      case RolloverStatus.initial:
        return (Colors.grey, 'Not Started');
      case RolloverStatus.checkingEligibility:
        return (Colors.blue, 'Checking');
      case RolloverStatus.pending:
        return (Colors.orange, 'Pending');
      case RolloverStatus.awaitingAdminApproval:
        return (Colors.blue, 'Awaiting Approval');
      case RolloverStatus.approved:
        return (Colors.green, 'Approved');
      case RolloverStatus.rejected:
        return (Colors.red, 'Rejected');
      case RolloverStatus.completed:
        return (Colors.green, 'Completed');
      case RolloverStatus.cancelled:
        return (Colors.grey, 'Cancelled');
      case RolloverStatus.failed:
        return (Colors.red, 'Failed');
    }
  }
}

/// Guarantor Consent Status Badge
class GuarantorStatusBadge extends StatelessWidget {
  final GuarantorConsentStatus status;
  final bool showIcon;

  const GuarantorStatusBadge({
    super.key,
    required this.status,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _getStatusConfig();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon)
          Icon(
            icon,
            size: 14,
            color: color,
          ),
        if (showIcon) const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  (Color, IconData, String) _getStatusConfig() {
    switch (status) {
      case GuarantorConsentStatus.pending:
        return (Colors.grey, Icons.pending, 'Pending');
      case GuarantorConsentStatus.invited:
        return (Colors.blue, Icons.send, 'Invited');
      case GuarantorConsentStatus.accepted:
        return (Colors.green, Icons.check_circle, 'Accepted');
      case GuarantorConsentStatus.declined:
        return (Colors.red, Icons.cancel, 'Declined');
      case GuarantorConsentStatus.expired:
        return (Colors.grey, Icons.timer_off, 'Expired');
    }
  }
}

/// Eligibility Checklist Item
class EligibilityCheckItem extends StatelessWidget {
  final bool isMet;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const EligibilityCheckItem({
    super.key,
    required this.isMet,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isMet ? CoopvestColors.success : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
                    color: isMet ? CoopvestColors.textPrimary : CoopvestColors.textSecondary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CoopvestColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Rollover Summary Card
class RolloverSummaryCard extends StatelessWidget {
  final LoanRollover rollover;

  const RolloverSummaryCard({super.key, required this.rollover});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rollover Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                RolloverStatusBadge(status: rollover.status),
              ],
            ),
            const Divider(height: 16),
            _buildSummaryRow('Original Principal', rollover.originalPrincipal),
            _buildSummaryRow('Outstanding Balance', rollover.outstandingBalance),
            _buildSummaryRow('Repayment %', '${rollover.repaymentPercentage.toStringAsFixed(1)}%'),
            const Divider(height: 16),
            _buildSummaryRow('New Tenure', '${rollover.newTenure} months'),
            _buildSummaryRow('New Interest Rate', '${rollover.newInterestRate}%'),
            _buildSummaryRow('New Monthly', rollover.newMonthlyRepayment),
            _buildSummaryRow('New Total', rollover.newTotalRepayment),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, dynamic value) {
    final formattedValue = value is double
        ? value.toString()
        : value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: CoopvestColors.textSecondary,
            ),
          ),
          Text(
            formattedValue,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Guarantor Card for List Display
class GuarantorCard extends StatelessWidget {
  final RolloverGuarantor guarantor;
  final bool showActions;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onReplace;

  const GuarantorCard({
    super.key,
    required this.guarantor,
    this.showActions = false,
    this.onAccept,
    this.onDecline,
    this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: CoopvestColors.primary.withAlpha((255 * 0.1).toInt()),
              child: Text(
                guarantor.guarantorName[0].toUpperCase(),
                style: const TextStyle(
                  color: CoopvestColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guarantor.guarantorName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    guarantor.guarantorPhone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CoopvestColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            GuarantorStatusBadge(status: guarantor.status),
            if (showActions && guarantor.status == GuarantorConsentStatus.declined)
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: onReplace,
                tooltip: 'Replace guarantor',
              ),
          ],
        ),
      ),
    );
  }
}

/// Progress Step Indicator for Rollover Flow
class RolloverProgressSteps extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const RolloverProgressSteps({
    super.key,
    required this.currentStep,
    this.steps = const [
      'Eligibility',
      'Request',
      'Guarantors',
      'Approval',
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;

        return Expanded(
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted || isCurrent
                      ? CoopvestColors.primary
                      : CoopvestColors.lightGray,
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent ? Colors.white : CoopvestColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[index],
                style: TextStyle(
                  fontSize: 10,
                  color: isCurrent ? CoopvestColors.primary : CoopvestColors.textSecondary,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Empty State Widget for Rollover
class RolloverEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final Widget? action;

  const RolloverEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: CoopvestColors.lightGray,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: CoopvestColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
