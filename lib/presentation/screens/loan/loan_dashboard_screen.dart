import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/loan_models.dart';
import '../../../presentation/providers/loan_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import 'loan_application_screen.dart';

/// Loan Dashboard Screen - View and manage all loan applications
class LoanDashboardScreen extends ConsumerWidget {
  final String userId;
  final String userName;
  final String userPhone;

  const LoanDashboardScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userPhone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanState = ref.watch(loanProvider);
    final loans = loanState.loans;
    
    // Calculate stats from real data
    final activeLoans = loans.where((l) => l.status == 'active' || l.status == 'repaying').length;
    final totalBorrowed = loans.fold(0.0, (sum, l) => sum + l.amount);
    final totalRepaid = loans.where((l) => l.status == 'completed').fold(0.0, (sum, l) => sum + l.totalRepayment);
    
    final _quickStats = {
      'totalLoans': loans.length,
      'activeLoans': activeLoans,
      'totalBorrowed': totalBorrowed,
      'totalRepaid': totalRepaid,
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'My Loans',
          style: CoopvestTypography.headlineLarge.copyWith(
            color: CoopvestColors.darkGray,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Active Loans',
                      '${_quickStats['activeLoans']}',
                      Icons.trending_up,
                      CoopvestColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Total Borrowed',
                      '₦${(_quickStats['totalBorrowed'] as num).toDouble().toStringAsFixed(0)}',
                      Icons.account_balance,
                      CoopvestColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Repaid',
                      '₦${(_quickStats['totalRepaid'] as num).toDouble().toStringAsFixed(0)}',
                      Icons.payments,
                      CoopvestColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Applications',
                      '${_quickStats['totalLoans']}',
                      Icons.description,
                      Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Apply New Loan Button
              PrimaryButton(
                label: '+ Apply for New Loan',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => LoanApplicationScreen(
                        userId: userId,
                        userName: userName,
                        userPhone: userPhone,
                      ),
                    ),
                  );
                },
                width: double.infinity,
              ),

              const SizedBox(height: 24),

              // Loan History Section
              Text(
                'Loan History',
                style: CoopvestTypography.titleMedium.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 16),

              // Loan List
              loans.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: loans.length,
                      itemBuilder: (context, index) {
                        final loan = loans[index];
                        return _buildLoanCard(context, loan);
                      },
                    ),

              const SizedBox(height: 24),

              // How It Works Section
              AppCard(
                backgroundColor: CoopvestColors.veryLightGray,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How Our Loans Work',
                      style: CoopvestTypography.titleMedium.copyWith(
                        color: CoopvestColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildHowItWorksStep(1, 'Apply for a loan'),
                    _buildHowItWorksStep(2, 'Share QR code with 3 guarantors'),
                    _buildHowItWorksStep(3, 'Guarantors confirm their guarantee'),
                    _buildHowItWorksStep(4, 'Loan is approved and disbursed'),
                    _buildHowItWorksStep(5, 'Repay in monthly installments'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return AppCard(
      backgroundColor: color.withAlpha((255 * 0.1).toInt()),
      border: Border.all(color: color.withAlpha((255 * 0.2).toInt())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: CoopvestTypography.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: CoopvestTypography.bodySmall.copyWith(
              color: CoopvestColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(BuildContext context, Loan loan) {
    final statusColor = _getStatusColor(loan.status);
    final loanType = loan.purpose != null ? '${loan.purpose}' : 'Quick Loan';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/loan-details',
            arguments: {'loanId': loan.id},
          );
        },
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loanType,
                          style: CoopvestTypography.titleMedium.copyWith(
                            color: CoopvestColors.darkGray,
                          ),
                        ),
                        Text(
                          'Loan ID: ${loan.id}',
                          style: CoopvestTypography.bodySmall.copyWith(
                            color: CoopvestColors.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha((255 * 0.1).toInt()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      loan.status,
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: statusColor,
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
                  _buildLoanDetail('Amount', '\u20a6${loan.amount.formatNumber()}'),
                  _buildLoanDetail('Monthly', '\u20a6${loan.monthlyRepayment.formatNumber()}'),
                  _buildLoanDetail('Guarantors', '${loan.guarantorsAccepted}/${loan.guarantorsRequired}'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Applied: ${_formatDate(loan.createdAt)}',
                style: CoopvestTypography.bodySmall.copyWith(
                  color: CoopvestColors.mediumGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoanDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CoopvestTypography.bodySmall.copyWith(
            color: CoopvestColors.mediumGray,
          ),
        ),
        Text(
          value,
          style: CoopvestTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: CoopvestColors.darkGray,
          ),
        ),
      ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet,
            color: CoopvestColors.mediumGray,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No Loan Applications',
            style: CoopvestTypography.titleMedium.copyWith(
              color: CoopvestColors.mediumGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t applied for any loans yet',
            style: CoopvestTypography.bodyMedium.copyWith(
              color: CoopvestColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(int step, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: CoopvestColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: CoopvestTypography.bodyMedium.copyWith(
                color: CoopvestColors.darkGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
