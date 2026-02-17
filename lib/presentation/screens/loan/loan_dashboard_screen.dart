import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/utils.dart' hide NumExtension;
import '../../../core/extensions/number_extensions.dart';
import '../../../data/models/loan_models.dart' hide LoanStatus;
import '../../../presentation/providers/loan_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import 'loan_application_screen.dart';

/// Loan Dashboard Screen - View and manage all loan applications
class LoanDashboardScreen extends ConsumerStatefulWidget {
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
  ConsumerState<LoanDashboardScreen> createState() => _LoanDashboardScreenState();
}

class _LoanDashboardScreenState extends ConsumerState<LoanDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loanProvider.notifier).getLoans();
    });
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        title: const Text('My Loans'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(loanProvider.notifier).getLoans();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total Borrowed',
                        '₦${(_quickStats['totalBorrowed'] as num).toDouble().toStringAsFixed(0)}',
                        Icons.account_balance,
                        CoopvestColors.primary,
                        onTap: () {},
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
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Applications',
                        '${_quickStats['totalLoans']}',
                        Icons.description,
                        Colors.orange,
                        onTap: () {},
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
                          userId: widget.userId,
                          userName: widget.userName,
                          userPhone: widget.userPhone,
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
                const SizedBox(height: 16),

                // Loan List
                loanState.status == LoanStatus.loading && loans.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : loans.isEmpty
                        ? _buildEmptyState(context)
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
                  backgroundColor: context.secondaryCardBackground,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How Our Loans Work',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      _buildHowItWorksStep(1, 'Apply for a loan', context),
                      _buildHowItWorksStep(2, 'Share QR code with 3 guarantors', context),
                      _buildHowItWorksStep(3, 'Guarantors confirm their guarantee', context),
                      _buildHowItWorksStep(4, 'Loan is approved and disbursed', context),
                      _buildHowItWorksStep(5, 'Repay in monthly installments', context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return AppCard(
      onTap: onTap,
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
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
      child: AppCard(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/loan-details',
            arguments: {'loanId': loan.id},
          );
        },
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
                        style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                      ),
                      Text(
                        'Loan ID: ${loan.id}',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    loan.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₦${loan.amount.formatNumber()}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${loan.createdAt.day}/${loan.createdAt.month}/${loan.createdAt.year}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.description_outlined, size: 48, color: context.textSecondary),
              const SizedBox(height: 16),
              Text(
                'No loan applications yet',
                style: TextStyle(color: context.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorksStep(int step, String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: CoopvestColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: context.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'repaying':
        return CoopvestColors.success;
      case 'pending':
      case 'awaiting_guarantors':
        return CoopvestColors.warning;
      case 'completed':
        return CoopvestColors.info;
      case 'rejected':
      case 'cancelled':
        return CoopvestColors.error;
      default:
        return CoopvestColors.mediumGray;
    }
  }
}
