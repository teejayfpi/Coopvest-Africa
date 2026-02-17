import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
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

    final _repaymentSchedule = [
      {'installment': 1, 'amount': 13125.0, 'dueDate': DateTime.now().subtract(const Duration(days: 25)), 'status': 'Paid'},
      {'installment': 2, 'amount': 13125.0, 'dueDate': DateTime.now().subtract(const Duration(days: 5)), 'status': 'Paid'},
      {'installment': 3, 'amount': 13125.0, 'dueDate': DateTime.now().add(const Duration(days: 5)), 'status': 'Due'},
      {'installment': 4, 'amount': 13125.0, 'dueDate': DateTime.now().add(const Duration(days: 35)), 'status': 'Upcoming'},
    ];

    final _guarantors = [
      {'name': 'John Smith', 'phone': '+2348012345678', 'status': 'Confirmed', 'confirmedAt': DateTime.now().subtract(const Duration(days: 20))},
      {'name': 'Jane Doe', 'phone': '+2348098765432', 'status': 'Confirmed', 'confirmedAt': DateTime.now().subtract(const Duration(days: 18))},
      {'name': 'Bob Wilson', 'phone': '+2348076543210', 'status': 'Confirmed', 'confirmedAt': DateTime.now().subtract(const Duration(days: 15))},
    ];

    final statusColor = _getStatusColor(loan.status);

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Loan Details',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                backgroundColor: statusColor.withOpacity(0.1),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loan.type,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            loan.status,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailItem(context, 'Loan ID', loan.id),
                        _buildDetailItem(context, 'Amount', '\u20a6${loan.amount.formatNumber()}'),
                        _buildDetailItem(context, 'Tenure', '${loan.tenure} months'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Repayment Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  children: [
                    _buildSummaryRow(context, 'Monthly Repayment', '\u20a6${loan.monthlyRepayment.formatNumber()}'),
                    Divider(height: 24, color: context.dividerColor),
                    _buildSummaryRow(context, 'Total Repayment', '\u20a6${loan.totalRepayment.formatNumber()}'),
                    Divider(height: 24, color: context.dividerColor),
                    _buildSummaryRow(context, 'Interest Rate', '${loan.interestRate}%'),
                    Divider(height: 24, color: context.dividerColor),
                    _buildSummaryRow(context, 'Next Payment Due', _formatDate(loan.nextRepaymentDate)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Repayment Schedule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 12),
              ..._repaymentSchedule.map((installment) => _buildInstallmentCard(context, installment)),

              const SizedBox(height: 24),

              Text(
                'Guarantors (${loan.guarantorsConfirmed}/${loan.guarantorsRequired})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 12),
              ..._guarantors.map((guarantor) => _buildGuarantorCard(context, guarantor)),

              const SizedBox(height: 32),

              if (loan.status == 'Active' || loan.status == 'Repaying')
                PrimaryButton(
                  label: 'Make Repayment',
                  onPressed: () {},
                  width: double.infinity,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
      ],
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.textSecondary)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
      ],
    );
  }

  Widget _buildInstallmentCard(BuildContext context, Map<String, dynamic> installment) {
    final statusColor = _getInstallmentStatusColor(installment['status'] as String);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${installment['installment']}',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\u20a6${(installment['amount'] as double).formatNumber()}', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                  Text('Due: ${_formatDate(installment['dueDate'] as DateTime)}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                installment['status'] as String,
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuarantorCard(BuildContext context, Map<String, dynamic> guarantor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: CoopvestColors.primary.withOpacity(0.1),
              child: const Icon(Icons.person, color: CoopvestColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(guarantor['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                  Text(guarantor['phone'] as String, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: CoopvestColors.success, size: 20),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'repaying':
        return CoopvestColors.success;
      case 'pending':
        return CoopvestColors.warning;
      case 'overdue':
        return CoopvestColors.error;
      default:
        return CoopvestColors.mediumGray;
    }
  }

  Color _getInstallmentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return CoopvestColors.success;
      case 'due':
        return CoopvestColors.warning;
      case 'upcoming':
        return CoopvestColors.primary;
      default:
        return CoopvestColors.mediumGray;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
