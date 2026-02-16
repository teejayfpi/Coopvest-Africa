import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/loan_models.dart' hide LoanStatus;
import '../../../presentation/providers/loan_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';

/// Loan Details Screen - View detailed information about a specific loan
class LoanDetailsScreen extends ConsumerWidget {
  final String loanId;

  const LoanDetailsScreen({
    super.key,
    required this.loanId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanState = ref.watch(loanProvider);
    final now = DateTime.now();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final loan = loanState.loans.firstWhere(
      (l) => l.id == loanId,
      orElse: () => Loan(
        id: loanId,
        userId: 'demo-user',
        amount: 50000,
        tenure: 4,
        interestRate: 5.0,
        monthlyRepayment: 13125,
        totalRepayment: 52500,
        status: 'Active',
        purpose: 'Business expansion',
        guarantorsAccepted: 3,
        guarantorsRequired: 3,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 25)),
        approvedAt: now.subtract(const Duration(days: 25)),
        disbursedAt: now.subtract(const Duration(days: 24)),
      ),
    );

    // Mock repayment schedule for demo
    final _repaymentSchedule = [
      {
        'installment': 1,
        'amount': 13125.0,
        'dueDate': DateTime.now().subtract(const Duration(days: 25)),
        'status': 'Paid'
      },
      {
        'installment': 2,
        'amount': 13125.0,
        'dueDate': DateTime.now().subtract(const Duration(days: 5)),
        'status': 'Paid'
      },
      {
        'installment': 3,
        'amount': 13125.0,
        'dueDate': DateTime.now().add(const Duration(days: 5)),
        'status': 'Due'
      },
      {
        'installment': 4,
        'amount': 13125.0,
        'dueDate': DateTime.now().add(const Duration(days: 35)),
        'status': 'Upcoming'
      },
    ];

    // Mock guarantors for demo
    final _guarantors = [
      {
        'name': 'John Smith',
        'phone': '+2348012345678',
        'status': 'Confirmed',
        'confirmedAt': DateTime.now().subtract(const Duration(days: 20))
      },
      {
        'name': 'Jane Doe',
        'phone': '+2348098765432',
        'status': 'Confirmed',
        'confirmedAt': DateTime.now().subtract(const Duration(days: 18))
      },
      {
        'name': 'Bob Wilson',
        'phone': '+2348076543210',
        'status': 'Confirmed',
        'confirmedAt': DateTime.now().subtract(const Duration(days: 15))
      },
    ];

    final statusColor = _getStatusColor(loan.status);

    return Scaffold(
      backgroundColor: isDarkMode ? CoopvestColors.darkBackground : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? CoopvestColors.darkSurface : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : CoopvestColors.darkGray),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Loan Details',
          style: CoopvestTypography.headlineLarge.copyWith(
            color: isDarkMode ? Colors.white : CoopvestColors.darkGray,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Loan Status Card
              AppCard(
                backgroundColor: isDarkMode ? CoopvestColors.darkSurface : statusColor.withAlpha((255 * 0.1).toInt()),
                border: Border.all(
                    color: isDarkMode ? CoopvestColors.darkDivider : statusColor.withAlpha((255 * 0.3).toInt())),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loan.type,
                          style: CoopvestTypography.headlineSmall.copyWith(
                            color: isDarkMode ? Colors.white : CoopvestColors.darkGray,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            loan.status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailItem('Loan ID', loan.id, isDarkMode),
                        _buildDetailItem(
                            'Amount', '\u20a6${loan.amount.formatNumber()}', isDarkMode),
                        _buildDetailItem('Tenure', '${loan.tenure} months', isDarkMode),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Repayment Summary
              Text(
                'Repayment Summary',
                style: CoopvestTypography.titleMedium.copyWith(
                  color: isDarkMode ? Colors.white : CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  children: [
                    _buildSummaryRow('Monthly Repayment',
                        '\u20a6${loan.monthlyRepayment.formatNumber()}', isDarkMode),
                    const Divider(height: 24),
                    _buildSummaryRow('Total Repayment',
                        '\u20a6${loan.totalRepayment.formatNumber()}', isDarkMode),
                    const Divider(height: 24),
                    _buildSummaryRow('Interest Rate', '${loan.interestRate}%', isDarkMode),
                    const Divider(height: 24),
                    _buildSummaryRow('Next Payment Due',
                        _formatDate(loan.nextRepaymentDate), isDarkMode),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Repayment Schedule
              Text(
                'Repayment Schedule',
                style: CoopvestTypography.titleMedium.copyWith(
                  color: isDarkMode ? Colors.white : CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 12),
              ..._repaymentSchedule
                  .map((installment) => _buildInstallmentCard(installment, isDarkMode)),

              const SizedBox(height: 24),

              // Guarantors Section
              Text(
                'Guarantors (${loan.guarantorsConfirmed}/${loan.guarantorsRequired})',
                style: CoopvestTypography.titleMedium.copyWith(
                  color: isDarkMode ? Colors.white : CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 12),
              ..._guarantors.map((guarantor) => _buildGuarantorCard(guarantor)),

              const SizedBox(height: 32),

              // Make Repayment Button
              if (loan.status == 'Active' || loan.status == 'Repaying')
                PrimaryButton(
                  label: 'Make Repayment',
                  onPressed: () {
                    // TODO: Navigate to repayment screen
                  },
                  width: double.infinity,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, [bool isDarkMode = false]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CoopvestTypography.bodySmall.copyWith(
            color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: CoopvestTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : CoopvestColors.darkGray,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, [bool isDarkMode = false]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: CoopvestTypography.bodyMedium.copyWith(
            color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
          ),
        ),
        Text(
          value,
          style: CoopvestTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : CoopvestColors.darkGray,
          ),
        ),
      ],
    );
  }

  Widget _buildInstallmentCard(Map<String, dynamic> installment, [bool isDarkMode = false]) {
    final statusColor =
        _getInstallmentStatusColor(installment['status'] as String);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${installment['installment']}',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Installment ${installment['installment']}',
                    style: CoopvestTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Due: ${_formatDate(installment['dueDate'] as DateTime)}',
                    style: CoopvestTypography.bodySmall.copyWith(
                      color: CoopvestColors.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '\u20a6${(installment['amount'] as num).toDouble().formatNumber()}',
              style: CoopvestTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                installment['status'] as String,
                style: CoopvestTypography.labelSmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuarantorCard(Map<String, dynamic> guarantor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CoopvestColors.primary.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.person,
                color: CoopvestColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guarantor['name'] as String,
                    style: CoopvestTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    guarantor['phone'] as String,
                    style: CoopvestTypography.bodySmall.copyWith(
                      color: CoopvestColors.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CoopvestColors.success.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle,
                      color: CoopvestColors.success, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Confirmed',
                    style: TextStyle(
                      color: CoopvestColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return CoopvestColors.success;
      case 'Repaying':
        return CoopvestColors.primary;
      case 'Completed':
        return CoopvestColors.info;
      case 'Pending':
        return Colors.orange;
      case 'Rejected':
        return CoopvestColors.error;
      default:
        return CoopvestColors.mediumGray;
    }
  }

  Color _getInstallmentStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return CoopvestColors.success;
      case 'Due':
        return Colors.orange;
      case 'Upcoming':
        return CoopvestColors.info;
      case 'Overdue':
        return CoopvestColors.error;
      default:
        return CoopvestColors.mediumGray;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
