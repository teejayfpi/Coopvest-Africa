import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../core/utils/utils.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../data/models/loan_models.dart';
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
                const Text(
                  'Loan History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Loan List
                loanState.isLoading && loans.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : loans.isEmpty
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
                  backgroundColor: Theme.of(context).brightness == Brightness.dark 
                      ? CoopvestColors.darkSurface 
                      : CoopvestColors.veryLightGray,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How Our Loans Work',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Loan ID: ${loan.id}',
                        style: TextStyle(
                          color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
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
                        color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₦${loan.amount.formatNumber()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date Applied',
                      style: TextStyle(
                        color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      Utils.formatDate(loan.createdAt),
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildEmptyState() {
    return AppCard(
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.description_outlined, size: 64, color: CoopvestColors.mediumGray),
            const SizedBox(height: 16),
            const Text(
              'No loans found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You haven\'t applied for any loans yet.',
              style: TextStyle(color: CoopvestColors.mediumGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksStep(int step, String description) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
              description,
              style: TextStyle(
                color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
              ),
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
      case 'completed':
        return CoopvestColors.success;
      case 'pending':
      case 'processing':
        return CoopvestColors.warning;
      case 'rejected':
      case 'cancelled':
        return CoopvestColors.error;
      default:
        return CoopvestColors.mediumGray;
    }
  }
}
