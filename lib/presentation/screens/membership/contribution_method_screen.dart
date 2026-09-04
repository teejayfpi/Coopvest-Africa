import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/kyc_models.dart';
import '../../providers/kyc_provider.dart';
import '../../widgets/common/buttons.dart';

/// Lets an active member switch their contribution channel:
///   Direct Deposit  ↔  Salary Deduction
///
/// Switching TO salary deduction collects the employment details the channel
/// needs and re-submits the KYC so an admin reviews the new employment
/// information (visible on the admin website).
class ContributionMethodScreen extends ConsumerStatefulWidget {
  const ContributionMethodScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ContributionMethodScreen> createState() =>
      _ContributionMethodScreenState();
}

class _ContributionMethodScreenState
    extends ConsumerState<ContributionMethodScreen> {
  String? _selected;
  bool _saving = false;

  final _employerCtrl = TextEditingController();
  final _staffIdCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _workAddressCtrl = TextEditingController();
  String? _employmentType;

  @override
  void initState() {
    super.initState();
    final sub = ref.read(kycProvider).submission;
    _selected = sub?.contributionType ?? 'direct_deposit';
    _employmentType =
        sub != null && sub.employmentType.isNotEmpty ? sub.employmentType : null;
    _employerCtrl.text = sub?.employerName ?? sub?.organizationName ?? '';
    _occupationCtrl.text = sub?.occupation ?? '';
    _workAddressCtrl.text = sub?.workAddress ?? '';
  }

  @override
  void dispose() {
    _employerCtrl.dispose();
    _staffIdCtrl.dispose();
    _occupationCtrl.dispose();
    _workAddressCtrl.dispose();
    super.dispose();
  }

  bool get _changed {
    final current =
        ref.read(kycProvider).submission?.contributionType ?? 'direct_deposit';
    return _selected != null && _selected != current;
  }

  Future<void> _save() async {
    if (_selected == null || !_changed) return;

    if (_selected == 'salary_deduction') {
      if (_employmentType == null || _employerCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Employment type and employer name are required for salary deduction.'),
            backgroundColor: CoopvestColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ref.read(kycProvider.notifier).switchContributionType(
        _selected!,
        employmentInfo: _selected == 'salary_deduction'
            ? {
                'employment_type': _employmentType,
                'employer_name': _employerCtrl.text.trim(),
                'employer_staff_id': _staffIdCtrl.text.trim(),
                'occupation': _occupationCtrl.text.trim(),
                'work_address': _workAddressCtrl.text.trim(),
              }
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selected == 'salary_deduction'
              ? 'Switched to Salary Deduction — your employment details were sent for review.'
              : 'Switched to Direct Deposit.'),
          backgroundColor: CoopvestColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not switch: $e'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current =
        ref.watch(kycProvider).submission?.contributionType ?? 'direct_deposit';

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Contribution Method'),
        backgroundColor: CoopvestColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Current: ${current == 'salary_deduction' ? 'Salary Deduction' : 'Direct Deposit'}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: CoopvestColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Direct Deposit',
              subtitle: 'You make payments yourself — transfer, card or USSD.',
              selected: _selected == 'direct_deposit',
              onTap: () => setState(() => _selected = 'direct_deposit'),
            ),
            const SizedBox(height: 12),
            _OptionCard(
              icon: Icons.business_center_outlined,
              title: 'Salary Deduction',
              subtitle:
                  'Your employer deducts from your salary monthly. Requires employment details.',
              selected: _selected == 'salary_deduction',
              onTap: () => setState(() => _selected = 'salary_deduction'),
            ),
            if (_selected == 'salary_deduction') ...[
              const SizedBox(height: 24),
              Text('Employment Details',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _employmentType,
                decoration: const InputDecoration(
                  labelText: 'Employment Type *',
                  border: OutlineInputBorder(),
                ),
                items: EmploymentTypes.types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _employmentType = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _employerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Employer / Organization Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _staffIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Staff ID (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _occupationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Occupation / Job Title (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _workAddressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Work Address (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Switching to salary deduction sends your employment details for admin review.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: CoopvestColors.textSecondary),
              ),
            ],
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Save',
              onPressed: _save,
              isLoading: _saving,
              isEnabled: _changed && !_saving,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? CoopvestColors.primary.withOpacity(0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? CoopvestColors.primary : CoopvestColors.lightGray,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: CoopvestColors.primary, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: CoopvestColors.textSecondary, height: 1.3)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? CoopvestColors.primary
                  : CoopvestColors.mediumGray,
            ),
          ],
        ),
      ),
    );
  }
}
