import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme_config.dart';
import '../../providers/kyc_provider.dart';
import '../../widgets/common/buttons.dart';

/// First step of the standalone KYC flow: the member picks how they'll fund
/// their contributions — Direct Deposit (pay manually) or Salary Deduction
/// (employer payroll). The choice drives the rest of the flow: salary
/// deduction requires the employment section, direct deposit skips it.
class KYCDeductionTypeScreen extends ConsumerStatefulWidget {
  const KYCDeductionTypeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<KYCDeductionTypeScreen> createState() =>
      _KYCDeductionTypeScreenState();
}

class _KYCDeductionTypeScreenState
    extends ConsumerState<KYCDeductionTypeScreen> {
  String? _selected; // 'direct_deposit' | 'salary_deduction'

  @override
  void initState() {
    super.initState();
    final existing = ref.read(kycProvider).submission?.contributionType;
    if (existing != null && existing.isNotEmpty) {
      _selected = existing;
    }
  }

  void _continue() {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select how you want to contribute'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }
    ref.read(kycProvider.notifier).updateContributionType(_selected!);
    // Salary-deduction members must give employment details; direct-deposit
    // members skip that section entirely. Either way, jump to the first
    // section that still has missing data.
    final submission = ref.read(kycProvider).submission;
    final missing = submission?.missingSections ?? const <String>[];
    final next = missing.isEmpty
        ? (_selected == 'salary_deduction'
            ? '/kyc-employment-details'
            : '/kyc-id-upload')
        : {
            'employment': _selected == 'salary_deduction'
                ? '/kyc-employment-details'
                // Direct-deposit members still need personal basics (DOB,
                // address) which the employment screen collects without
                // requiring the payroll fields.
                : '/kyc-employment-details',
            'identification': '/kyc-id-upload',
            'nextOfKin': '/kyc-next-of-kin',
            'bank': '/kyc-bank-info',
          }[missing.first]!;
    Navigator.of(context).pushReplacementNamed(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Contribution Method',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: CoopvestColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How do you want to make your contributions?',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'You can change this later from your membership settings.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: CoopvestColors.textSecondary),
              ),
              const SizedBox(height: 28),
              _TypeCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Direct Deposit',
                subtitle:
                    'You make payments yourself — bank transfer, card, or USSD, whenever it suits you.',
                badge: 'No employment details needed',
                selected: _selected == 'direct_deposit',
                onTap: () => setState(() => _selected = 'direct_deposit'),
              ),
              const SizedBox(height: 16),
              _TypeCard(
                icon: Icons.business_center_outlined,
                title: 'Salary Deduction',
                subtitle:
                    'Your employer deducts the contribution from your salary every month and remits it for you.',
                badge: 'Requires employment details',
                selected: _selected == 'salary_deduction',
                onTap: () => setState(() => _selected = 'salary_deduction'),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Continue',
                onPressed: _continue,
                isEnabled: _selected != null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? CoopvestColors.primary.withOpacity(0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? CoopvestColors.primary : CoopvestColors.lightGray,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CoopvestColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: CoopvestColors.primary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected
                            ? CoopvestColors.primary
                            : CoopvestColors.mediumGray,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: CoopvestColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: CoopvestColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 11,
                        color: CoopvestColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
}
