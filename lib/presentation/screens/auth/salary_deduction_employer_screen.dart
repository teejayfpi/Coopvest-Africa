import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/services/terms_acceptance_store.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/kyc_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kyc_provider.dart';
import '../../widgets/common/buttons.dart';

/// Employer selection, shown immediately after the member chooses Salary
/// Deduction on the contribution screen.
///
/// WHY THIS SCREEN EXISTS
/// ----------------------
/// Salary deduction means the employer deducts the contribution (and the
/// registration fee) from salary and remits it. That requires an employer on
/// file: `profiles.organization_id`, or a pending enrolment request when the
/// employer is not enrolled yet.
///
/// The shortened sign-up path used to skip this entirely. The member picked
/// Salary Deduction, the app posted the choice with no employment details, the
/// backend rejected it (employment details are required for salary deduction)
/// and the app swallowed the error — so the member arrived at the payment
/// screen with no channel and no employer on their profile, and was asked to
/// pay the ₦5,000 fee that was going to be deducted from their salary anyway.
///
/// Collecting the employer here closes that gap: the choice and the employer
/// are recorded together before payment, so the registration-fee exemption can
/// actually fire and the member is not asked for money twice.
class SalaryDeductionEmployerScreen extends ConsumerStatefulWidget {
  final Map<String, String> registrationData;

  const SalaryDeductionEmployerScreen({
    Key? key,
    required this.registrationData,
  }) : super(key: key);

  @override
  ConsumerState<SalaryDeductionEmployerScreen> createState() =>
      _SalaryDeductionEmployerScreenState();
}

class _SalaryDeductionEmployerScreenState
    extends ConsumerState<SalaryDeductionEmployerScreen> {
  final _searchCtrl = TextEditingController();

  List<Organization> _organizations = const [];
  bool _loading = true;
  String? _loadError;

  Organization? _selected;
  String _employmentType = EmploymentTypes.types.last; // 'Permanent'

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizations() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final orgs = await ref.read(kycProvider.notifier).loadOrganizations();
      if (!mounted) return;
      setState(() {
        _organizations = orgs;
        _loading = false;
      });
    } catch (e) {
      logger.w('Could not load employers: $e');
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load employers. Please try again.';
        _loading = false;
      });
    }
  }

  List<Organization> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _organizations;
    return _organizations.where((o) {
      return o.name.toLowerCase().contains(query) ||
          (o.code ?? '').toLowerCase().contains(query);
    }).toList();
  }

  /// Save the channel + employer, then continue to the rest of sign-up.
  ///
  /// A member whose employer is not enrolled is still allowed through: the
  /// employer is recorded as a pending request, which counts as an employer on
  /// file for the fee exemption because payroll will recover it once they are
  /// enrolled. Blocking here would strand them over an admin step.
  Future<void> _save({String? pendingEmployerName}) async {
    if (_selected == null && (pendingEmployerName ?? '').trim().isEmpty) return;

    setState(() => _saving = true);
    final employerName = _selected?.name ?? (pendingEmployerName ?? '').trim();

    try {
      final acceptance = await TermsAcceptanceStore.load();

      await ref.read(kycProvider.notifier).switchContributionType(
            'salary_deduction',
            employmentInfo: {
              'employment_type': _employmentType,
              'employer_name': employerName,
              if (_selected != null) 'organization_id': _selected!.id,
            },
            termsVersion: acceptance?.version,
            termsAcceptedAt: acceptance?.acceptedAt,
          );

      // Recorded — drop the local hand-off so it is not forwarded twice.
      if (acceptance != null) await TermsAcceptanceStore.clear();
    } catch (e) {
      // Deliberately not fatal. The save posts the channel and employer first
      // and only then re-reads KYC status, so a failure here can be the
      // follow-up read rather than the write. Whether the employer actually
      // landed is settled by the refresh below, not by this exception —
      // surfacing it directly would trap the member on this screen with their
      // employer already saved.
      logger.e('Salary deduction employer save error: $e');
    }

    // Refresh so the activation gate sees the employer and the exemption takes
    // effect on this pass.
    await ref.read(authProvider.notifier).refreshCurrentUser();
    if (!mounted) return;

    if (ref.read(authProvider).user?.hasSettledRegistrationFee ?? false) {
      Navigator.of(context).pushReplacementNamed(
        '/signup-details',
        arguments: Map<String, String>.from(widget.registrationData)
          ..['contribution_type'] = 'salary_deduction'
          ..['employer_name'] = employerName,
      );
      return;
    }

    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Could not save your employer. Please check your connection and try again.'),
        backgroundColor: CoopvestColors.error,
      ),
    );
  }

  /// Ask us to enrol an employer that is not in the list.
  Future<void> _requestEmployer() async {
    final controller = TextEditingController(text: _searchCtrl.text.trim());
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
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(kycProvider.notifier)
          .requestOrganizationApproval(name);
    } catch (e) {
      // Non-fatal: the employer still gets recorded on the profile by _save,
      // which is what the fee exemption reads. The request is a courtesy so we
      // can chase enrolment.
      logger.w('Request employer failed (non-fatal): $e');
    }

    if (!mounted) return;
    setState(() => _saving = false);
    await _save(pendingEmployerName: name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.scaffoldBackground,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Your Employer',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Who do you work for?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your employer deducts your contribution from your salary '
                    'and sends it to Coopvest. Your registration fee is also '
                    'recovered this way, so you do not pay it in the app.',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildEmploymentType(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Search employer',
                      hintText: 'Type your employer name',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmploymentType() {
    return DropdownButtonFormField<String>(
      initialValue: _employmentType,
      decoration: const InputDecoration(labelText: 'Employment type'),
      items: EmploymentTypes.types
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _employmentType = v);
      },
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _message(
        icon: Icons.cloud_off,
        title: 'Could not load employers',
        body: _loadError!,
        actionLabel: 'Try again',
        onAction: _loadOrganizations,
      );
    }

    final results = _filtered;

    if (results.isEmpty) {
      final typed = _searchCtrl.text.trim();
      return _message(
        icon: _organizations.isEmpty
            ? Icons.business_outlined
            : Icons.search_off,
        title: _organizations.isEmpty
            ? 'No employers enrolled yet'
            : 'No match found',
        body: typed.isEmpty
            ? 'No employers are enrolled for salary deduction yet. Request '
                'yours below and we will contact them.'
            : '"$typed" is not enrolled yet. You can request them below.',
        actionLabel: typed.isEmpty ? 'Request my employer' : 'Request "$typed"',
        onAction: _requestEmployer,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final org = results[index];
        final selected = _selected?.id == org.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => setState(() => _selected = org),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected
                    ? CoopvestColors.primary.withValues(alpha: 0.07)
                    : context.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      selected ? CoopvestColors.primary : context.dividerColor,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.business_center_outlined,
                    color: selected
                        ? CoopvestColors.primary
                        : context.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.name,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (org.code != null && org.code!.isNotEmpty)
                          Text(
                            org.code!,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        color: CoopvestColors.primary, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: context.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: 'Continue',
            onPressed: () => _save(),
            width: double.infinity,
            isLoading: _saving,
            isEnabled: _selected != null && !_saving,
          ),
          const SizedBox(height: 8),
          Text(
            'Not enrolled? Request your employer and you can still continue.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
