import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

/// Loan Application Status - shows progress of loan through stages
class LoanApplicationStatus extends StatelessWidget {
  final String status; // draft, pending_guarantors, guarantors_confirmed, under_review, approved, rejected, active, repaying, completed, defaulted
  final int guarantorsConfirmed;
  final int guarantorsRequired;
  final VoidCallback? onTap;

  const LoanApplicationStatus({
    super.key,
    required this.status,
    this.guarantorsConfirmed = 0,
    this.guarantorsRequired = 3,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance, color: CoopvestColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Loan Application',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  _buildStatusChip(),
                ],
              ),
              const SizedBox(height: 16),
              _buildProgressSteps(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getStatusLabel(),
        style: TextStyle(
          color: _getStatusColor(),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProgressSteps() {
    final currentStep = _getCurrentStepIndex();

    return Column(
      children: [
        _buildStep(0, 'Submitted', Icons.check_circle, currentStep),
        _buildConnector(currentStep >= 1),
        _buildStep(1, 'Guarantors', Icons.people, currentStep,
            subtitle: '$guarantorsConfirmed/$guarantorsRequired confirmed'),
        _buildConnector(currentStep >= 2),
        _buildStep(2, 'Under Review', Icons.rate_review, currentStep),
        _buildConnector(currentStep >= 3),
        _buildStep(3, 'Decision', Icons.gavel, currentStep),
      ],
    );
  }

  Widget _buildStep(int stepIndex, String label, IconData icon, int currentStep,
      {String? subtitle}) {
    final isCompleted = stepIndex < currentStep;
    final isCurrent = stepIndex == currentStep;
    final isPending = stepIndex > currentStep;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? CoopvestColors.primary
                : isCurrent
                    ? CoopvestColors.primary.withOpacity(0.2)
                    : Colors.grey.shade200,
            border: isCurrent
                ? Border.all(color: CoopvestColors.primary, width: 2)
                : null,
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isCompleted
                ? Colors.white
                : isCurrent
                    ? CoopvestColors.primary
                    : Colors.grey,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isPending ? Colors.grey : Colors.black87,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPending ? Colors.grey : CoopvestColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(left: 19),
      child: Container(
        width: 2,
        height: 24,
        color: isCompleted ? CoopvestColors.primary : Colors.grey.shade300,
      ),
    );
  }

  int _getCurrentStepIndex() {
    switch (status) {
      case 'draft':
        return 0;
      case 'pending_guarantors':
        return 1;
      case 'guarantors_confirmed':
        return 2;
      case 'under_review':
        return 2;
      case 'approved':
      case 'active':
      case 'repaying':
        return 3;
      case 'rejected':
        return -1; // Special case - shows as rejected
      case 'completed':
        return 3;
      case 'defaulted':
        return -2; // Special case
      default:
        return 0;
    }
  }

  String _getStatusLabel() {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'pending_guarantors':
        return 'Awaiting Guarantors';
      case 'guarantors_confirmed':
        return 'Guarantors Ready';
      case 'under_review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'active':
        return 'Active';
      case 'repaying':
        return 'Repaying';
      case 'completed':
        return 'Completed';
      case 'defaulted':
        return 'Defaulted';
      default:
        return status;
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'pending_guarantors':
        return Colors.orange;
      case 'guarantors_confirmed':
        return Colors.blue;
      case 'under_review':
        return Colors.purple;
      case 'approved':
      case 'active':
      case 'repaying':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'defaulted':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }
}

/// Compact loan status card for lists
class LoanStatusCard extends StatelessWidget {
  final String loanId;
  final String amount;
  final String status;
  final String? progress;
  final VoidCallback? onTap;

  const LoanStatusCard({
    super.key,
    required this.loanId,
    required this.amount,
    required this.status,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loanId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amount,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: double.tryParse(progress ?? '0') ?? 0,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(_getStatusColor()),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusLabel(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case 'active':
      case 'approved':
        return Colors.green;
      case 'pending_guarantors':
      case 'under_review':
        return Colors.orange;
      case 'rejected':
      case 'defaulted':
        return Colors.red;
      case 'repaying':
        return Colors.blue;
      case 'completed':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case 'active':
      case 'approved':
        return Icons.check_circle;
      case 'pending_guarantors':
      case 'under_review':
        return Icons.pending;
      case 'rejected':
      case 'defaulted':
        return Icons.cancel;
      case 'repaying':
        return Icons.currency_exchange;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.description;
    }
  }

  String _getStatusLabel() {
    return status.replaceAll('_', ' ').toUpperCase();
  }
}