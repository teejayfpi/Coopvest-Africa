import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/kyc_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kyc_provider.dart';
import '../../widgets/common/buttons.dart';

/// Lets an active member manage their contribution channel:
///   Direct Deposit  ↔  Salary Deduction
///
/// Switching TO salary deduction collects the employment details the channel
/// needs and re-submits the KYC so an admin reviews the new employment
/// information (visible on the admin website).
///
/// It also lets a member who is *already* on salary deduction change their
/// employer without touching the channel. That case matters: `organization_id`
/// drives both payroll deduction and the same-organisation guarantor rule, so a
/// member who changes jobs and cannot update their employer stays attached to
/// the one they left.
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

  /// The enrolled employer the member has picked, if any. When set, its id is
  /// sent so the profile links to the organisation (payroll + the
  /// same-organisation guarantor rule need the link, not just the name). Left
  /// null for an employer that is not enrolled — that is recorded as a pending
  /// name instead.
  Organization? _selectedOrg;

  /// The employer originally on file, so an employer-only change is detected
  /// even when the channel is not switched. Captured in [initState].
  late final String _initialEmployer;
  late final String? _initialOrgId;

  @override
  void initState() {
    super.initState();
    final sub = ref.read(kycProvider).submission;
    _selected = sub?.contributionType ?? 'direct_deposit';
    _employmentType =
        sub != null && sub.employmentType.isNotEmpty ? sub.employmentType : null;
    _employerCtrl.text = sub?.employerName ?? sub?.organizationName ?? '';
    _initialEmployer = _employerCtrl.text.trim();
    _initialOrgId = sub?.organizationId;
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

  /// True when a member already on salary deduction has edited their employer.
  ///
  /// This is the job-change path: the channel is unchanged, so [_changed] is
  /// false, but the employer must still be re-submitted for review.
  ///
  /// The organisation id is only compared once the member has actually picked
  /// one. Comparing it unconditionally would flag the screen dirty on open for
  /// a member who is already linked, because [_selectedOrg] starts null.
  bool get _employerChanged =>
      _selected == 'salary_deduction' &&
      (_employerCtrl.text.trim() != _initialEmployer ||
          (_selectedOrg != null && _selectedOrg!.id != _initialOrgId));

  Future<void> _pickEmployer() async {
    final org = await showModalBottomSheet<Organization>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EmployerPickerSheet(
        organizations: ref.read(kycProvider).organizations,
        onLoad: () => ref.read(kycProvider.notifier).loadOrganizations(),
      ),
    );
    if (org == null || !mounted) return;
    setState(() {
      _selectedOrg = org;
      _employerCtrl.text = org.name;
    });
  }

  /// Ask us to enrol an employer that is not in the list. Mirrors the sign-up
  /// employer screen: the request is a courtesy so we can chase enrolment, and
  /// the name is still saved as a pending employer.
  Future<void> _requestEmployer() async {
    final controller = TextEditingController(text: _employerCtrl.text.trim());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request your employer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your employer is not enrolled with Coopvest yet. Send us the '
              'name and we will contact them. Your salary deduction can start '
              'once they are enrolled.',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Employer name',
                hintText: 'e.g. Lagos State Ministry of Finance',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = controller.text.trim();
    if (name.isEmpty || !mounted) return;

    try {
      await ref.read(kycProvider.notifier).requestOrganizationApproval(name);
    } catch (e) {
      // Non-fatal: the employer is still recorded as pending when saved, which
      // is what the fee exemption reads.
      logger.w('Request employer failed (non-fatal): $e');
    }
    if (!mounted) return;
    setState(() {
      _selectedOrg = null;
      _employerCtrl.text = name;
    });
  }

  Future<void> _save() async {
    if (_selected == null) return;
    // Capture the intent before the request: `switchContributionType` updates
    // the provider on success, so `_changed` would read false afterwards and
    // every save would report itself as an employer-only change.
    final wasChannelChange = _changed;
    if (!wasChannelChange && !_employerChanged) return;

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
      final result = await ref.read(kycProvider.notifier).switchContributionType(
        _selected!,
        employmentInfo: _selected == 'salary_deduction'
            ? {
                'employment_type': _employmentType,
                'employer_name': _employerCtrl.text.trim(),
                // Only send the id for an employer the member actually picked
                // from the enrolled list. The backend re-checks that it is a
                // real, active organisation before linking it, and records a
                // pending name when it is not.
                if (_selectedOrg != null) 'organization_id': _selectedOrg!.id,
                'employer_staff_id': _staffIdCtrl.text.trim(),
                'occupation': _occupationCtrl.text.trim(),
                'work_address': _workAddressCtrl.text.trim(),
              }
            : null,
      );
      // Refresh the cached user so the gate reflects the new channel/employer
      // without a relaunch — the same reason the sign-up employer screen does.
      await ref.read(authProvider.notifier).refreshCurrentUser();
      if (!mounted) return;

      final successMessage = wasChannelChange
          ? (_selected == 'salary_deduction'
              ? 'Switched to Salary Deduction — your employment details were sent for review.'
              : 'Switched to Direct Deposit.')
          : 'Employer updated — your new employment details were sent for review.';

      // A change that affects an active loan is flagged by the backend: the
      // member's guarantors consented under the previous details and may need
      // re-sourcing. Show it prominently and keep it up longer than a toast.
      if (result.guarantorReviewRequired) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Your guarantors may need updating'),
            content: Text(
              result.warning ??
                  'Because you have an active loan, our team will review your '
                      'guarantors. They may need to be replaced.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: CoopvestColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
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
                initialValue: _employmentType,
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
                readOnly: true,
                onTap: _pickEmployer,
                decoration: InputDecoration(
                  labelText: 'Employer / Organization *',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  helperText: _selectedOrg == null
                      ? 'Tap to choose from enrolled employers'
                      : 'Linked to an enrolled employer',
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _requestEmployer,
                  icon: const Icon(Icons.add_business_outlined, size: 18),
                  label: const Text('My employer is not listed'),
                ),
              ),
              const SizedBox(height: 8),
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
                _changed
                    ? 'Switching to salary deduction sends your employment details for admin review.'
                    : 'Changing your employer sends the new details for admin review.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: CoopvestColors.textSecondary),
              ),
            ],
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Save',
              onPressed: _save,
              isLoading: _saving,
              isEnabled: (_changed || _employerChanged) && !_saving,
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
              ? CoopvestColors.primary.withValues(alpha: 0.06)
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

/// Bottom sheet that lists enrolled employers so a member can link one.
///
/// Picking an enrolled employer is what lets the profile store a real
/// `organization_id` rather than a free-text name: payroll deduction and the
/// same-organisation guarantor rule both read the link.
class _EmployerPickerSheet extends StatefulWidget {
  final List<Organization> organizations;
  final Future<List<Organization>> Function() onLoad;

  const _EmployerPickerSheet({
    required this.organizations,
    required this.onLoad,
  });

  @override
  State<_EmployerPickerSheet> createState() => _EmployerPickerSheetState();
}

class _EmployerPickerSheetState extends State<_EmployerPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<Organization> _organizations;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _organizations = widget.organizations;
    if (_organizations.isEmpty) _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orgs = await widget.onLoad();
      if (!mounted) return;
      setState(() {
        _organizations = orgs;
        _loading = false;
      });
    } catch (e) {
      logger.w('Could not load employers: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Organization> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _organizations;
    return _organizations
        .where((o) =>
            o.name.toLowerCase().contains(query) ||
            (o.code ?? '').toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _filtered;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Choose your employer',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search employer',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _organizations.isEmpty
                                  ? 'No employers are enrolled yet. Use "My employer is not listed" to request one.'
                                  : 'No match found.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: context.textSecondary, fontSize: 13),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final org = results[index];
                            return ListTile(
                              leading:
                                  const Icon(Icons.business_center_outlined),
                              title: Text(org.name),
                              subtitle:
                                  (org.code != null && org.code!.isNotEmpty)
                                      ? Text(org.code!)
                                      : null,
                              onTap: () => Navigator.of(context).pop(org),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
