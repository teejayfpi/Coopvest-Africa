import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import 'ticket_list_screen.dart';
import 'ticket_creation_screen.dart';

/// Support Home Screen
class SupportHomeScreen extends ConsumerWidget {
  const SupportHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Support Center', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [CoopvestColors.primary, CoopvestColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.headset_mic, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('How can we help?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Create a support ticket and our team will assist you.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TicketCreationScreen())),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Create New Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: CoopvestColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TicketListScreen())),
                  icon: const Icon(Icons.inbox_outlined),
                  label: const Text('My Tickets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 32),
              Text('Common Help Topics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 16),
              _buildHelpTopic(context, Icons.account_balance_wallet, 'Loans & Credit', 'Loan applications, repayments, guarantor requests'),
              _buildHelpTopic(context, Icons.group_add, 'Guarantor Requests', 'Being a guarantor, consent issues'),
              _buildHelpTopic(context, Icons.verified_user, 'Account & KYC', 'Profile updates, identity verification'),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: context.cardBackground, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: context.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Response Time', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                          Text('We typically respond within 24 hours on business days.', style: TextStyle(fontSize: 13, color: context.textSecondary)),
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

  Widget _buildHelpTopic(BuildContext context, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.dividerColor)),
          child: Row(
            children: [
              Icon(icon, color: CoopvestColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                    Text(description, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
