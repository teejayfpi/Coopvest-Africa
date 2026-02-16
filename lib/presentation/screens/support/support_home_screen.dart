import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import 'ticket_list_screen.dart';
import 'ticket_creation_screen.dart';

/// Support Home Screen
/// Main entry point for the support system
class SupportHomeScreen extends ConsumerWidget {
  const SupportHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
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
          'Support Center',
          style: TextStyle(
            color: isDarkMode ? Colors.white : CoopvestColors.darkGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CoopvestColors.primary,
                      CoopvestColors.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((255 * 0.2).toInt()),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.headset_mic,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'How can we help?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Create a support ticket and our team will assist you.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Quick Actions
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 16),

              // Create Ticket Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TicketCreationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Create New Ticket',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CoopvestColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // My Tickets Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TicketListScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.inbox_outlined, color: CoopvestColors.primary),
                  label: const Text(
                    'My Tickets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CoopvestColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CoopvestColors.primary,
                    side: const BorderSide(color: CoopvestColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Help Topics
              Text(
                'Common Help Topics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 16),

              _buildHelpTopic(
                icon: Icons.account_balance_wallet,
                title: 'Loans & Credit',
                description: 'Loan applications, repayments, guarantor requests',
                onTap: () => _createTicketWithCategory(
                  context,
                  'loan_issue',
                  'Loan Issue',
                ),
              ),
              const SizedBox(height: 12),

              _buildHelpTopic(
                icon: Icons.group_add,
                title: 'Guarantor Requests',
                description: 'Being a guarantor, consent issues',
                onTap: () => _createTicketWithCategory(
                  context,
                  'guarantor_consent',
                  'Guarantor Consent Issue',
                ),
              ),
              const SizedBox(height: 12),

              _buildHelpTopic(
                icon: Icons.share,
                title: 'Referrals & Bonuses',
                description: 'Referral codes, bonus tracking',
                onTap: () => _createTicketWithCategory(
                  context,
                  'referral_bonus',
                  'Referral/Bonus Issue',
                ),
              ),
              const SizedBox(height: 12),

              _buildHelpTopic(
                icon: Icons.payment,
                title: 'Repayments',
                description: 'Payment issues, transaction history',
                onTap: () => _createTicketWithCategory(
                  context,
                  'repayment_issue',
                  'Repayment Issue',
                ),
              ),
              const SizedBox(height: 12),

              _buildHelpTopic(
                icon: Icons.verified_user,
                title: 'Account & KYC',
                description: 'Profile updates, identity verification',
                onTap: () => _createTicketWithCategory(
                  context,
                  'account_kyc',
                  'Account/KYC Issue',
                ),
              ),
              const SizedBox(height: 12),

              _buildHelpTopic(
                icon: Icons.bug_report,
                title: 'Technical Issues',
                description: 'App bugs, login problems',
                onTap: () => _createTicketWithCategory(
                  context,
                  'technical_bug',
                  'Technical Bug Report',
                ),
              ),

              const SizedBox(height: 32),

              // Contact Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? CoopvestColors.darkSurface : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Response Time',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'We typically respond within 24 hours on business days.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpTopic({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: isDarkMode ? CoopvestColors.darkDivider : CoopvestColors.lightGray),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: CoopvestColors.primaryLight.withAlpha((255 * 0.1).toInt()),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: CoopvestColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? CoopvestColors.darkTextSecondary : CoopvestColors.mediumGray,
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _createTicketWithCategory(
    BuildContext context,
    String category,
    String categoryName,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TicketCreationScreen(
          preselectedCategory: category,
          preselectedCategoryName: categoryName,
        ),
      ),
    );
  }
}
