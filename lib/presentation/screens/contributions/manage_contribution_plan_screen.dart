import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../data/api/contributions/contribution_plan_api_service.dart';
import '../../../presentation/providers/contributions/contribution_plan_provider.dart';
import '../../../presentation/providers/loan_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';

/// Manage Contribution Plan Screen
/// Allows members to increase their monthly contribution (immediately)
/// or submit a reduction request (3-month notice, blocked if active loan).
class ManageContributionPlanScreen extends ConsumerStatefulWidget {
  const ManageContributionPlanScreen({super.key});

  @override
  ConsumerState<ManageContributionPlanScreen> createState() =>
      _ManageContributionPlanScreenState();
}

class _ManageContributionPlanScreenState
    extends ConsumerState<ManageContributionPlanScreen> {
  @override
  void initState() {
    super.initState();
    // Load plan and loan data
    Future.microtask(() {
      ref.read(contributionPlanProvider.notifier).load();
      ref.read(loanProvider.notifier).getLoans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(contributionPlanProvider);

    // Show snackbars for feedback
    ref.listen<ContributionPlanState>(contributionPlanProvider, (prev, next) {
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.successMessage!),
          backgroundColor: CoopvestColors.success,
          duration: const Duration(seconds: 4),
        ));
        ref.read(contributionPlanProvider.notifier).clearMessages();
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: CoopvestColors.error,
          duration: const Duration(seconds: 5),
        ));
        ref.read(contributionPlanProvider.notifier).clearMessages();
      }
    });

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
          'Manage Contribution Plan',
          style: TextStyle(
              color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: planState.isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: CoopvestColors.primary))
          : RefreshIndicator(
              color: CoopvestColors.primary,
              onRefresh: () =>
                  ref.read(contributionPlanProvider.notifier).load(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CurrentAmountCard(plan: planState.plan),
                    const SizedBox(height: 20),
                    if (planState.plan?.pendingReduction != null)
                      _PendingReductionBanner(
                          pending: planState.plan!.pendingReduction!),
                    if (planState.plan?.pendingReduction != null)
                      const SizedBox(height: 20),
                    _PolicyInfoBox(),
                    const SizedBox(height: 24),
                    Text(
                      'Change Your Contribution',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _IncreaseCard(plan: planState.plan),
                    const SizedBox(height: 16),
                    _ReductionCard(plan: planState.plan),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Current amount header card
// ---------------------------------------------------------------------------
class _CurrentAmountCard extends StatelessWidget {
  final ContributionPlan? plan;
  const _CurrentAmountCard({this.plan});

  @override
  Widget build(BuildContext context) {
    final amount = plan?.currentMonthlyAmount ?? 5000.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CoopvestColors.primary, Color(0xFF1A6B4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CoopvestColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Monthly Contribution',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '₦${amount.formatNumber()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'per month',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Minimum: ₦5,000 / month',
              style: TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending reduction banner
// ---------------------------------------------------------------------------
class _PendingReductionBanner extends ConsumerWidget {
  final PendingReductionRequest pending;
  const _PendingReductionBanner({required this.pending});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(contributionPlanProvider.notifier);
    final isSaving = ref.watch(contributionPlanProvider).isSaving;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CoopvestColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: CoopvestColors.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule,
                  color: CoopvestColors.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pending Reduction Request',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(context, 'Requested amount',
              '₦${pending.requestedAmount.formatNumber()}'),
          const SizedBox(height: 4),
          _infoRow(context, 'Effective from',
              _fmtDate(pending.effectiveDate)),
          const SizedBox(height: 4),
          _infoRow(context, 'Months remaining',
              '${pending.monthsRemaining} month(s)'),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: isSaving
                ? null
                : () => _confirmCancel(context, notifier),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: CoopvestColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: CoopvestColors.error.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel_outlined,
                      color: CoopvestColors.error, size: 16),
                  SizedBox(width: 6),
                  Text('Cancel Request',
                      style: TextStyle(
                          color: CoopvestColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(
      BuildContext context, ContributionPlanNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Reduction Request'),
        content: const Text(
            'Are you sure you want to cancel your pending contribution reduction request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              notifier.cancelReductionRequest();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: CoopvestColors.error,
                foregroundColor: Colors.white),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: TextStyle(
                  color: context.textSecondary, fontSize: 12)),
        ),
        Text(value,
            style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Policy info box
// ---------------------------------------------------------------------------
class _PolicyInfoBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: CoopvestColors.info.withOpacity(0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.policy_outlined,
                  color: CoopvestColors.info, size: 18),
              SizedBox(width: 8),
              Text(
                'Contribution Policy',
                style: TextStyle(
                  color: CoopvestColors.info,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _policyRow(
              Icons.check_circle_outline, CoopvestColors.success,
              'Increases take effect immediately and can be made at any time.'),
          const SizedBox(height: 6),
          _policyRow(
              Icons.schedule, CoopvestColors.warning,
              'Reductions require a 3-month notice period before taking effect.'),
          const SizedBox(height: 6),
          _policyRow(
              Icons.block, CoopvestColors.error,
              'You cannot reduce contributions while you have an active loan.'),
          const SizedBox(height: 6),
          _policyRow(
              Icons.money_off, CoopvestColors.info,
              'The minimum monthly contribution is ₦5,000.'),
        ],
      ),
    );
  }

  Widget _policyRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: CoopvestColors.info,
                  fontSize: 12,
                  height: 1.4)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Increase contribution action card
// ---------------------------------------------------------------------------
class _IncreaseCard extends ConsumerWidget {
  final ContributionPlan? plan;
  const _IncreaseCard({this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ActionCard(
      icon: Icons.trending_up,
      iconColor: CoopvestColors.success,
      title: 'Increase Contribution',
      subtitle: 'Takes effect immediately. No restrictions.',
      badgeText: 'Anytime',
      badgeColor: CoopvestColors.success,
      onTap: () => _showIncreaseSheet(context, ref),
    );
  }

  void _showIncreaseSheet(BuildContext context, WidgetRef ref) {
    final current = plan?.currentMonthlyAmount ?? 5000.0;
    final ctrl = TextEditingController();
    double? selected;
    final presets = _presetsAbove(current);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return _BottomSheetContainer(
            title: 'Increase Monthly Contribution',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: ₦${current.formatNumber()} / month',
                  style: TextStyle(
                      color: ctx.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (presets.isNotEmpty) ...[
                  Text('Quick Select',
                      style: TextStyle(
                          color: ctx.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: presets.map((amt) {
                      final isSelected = selected == amt;
                      return GestureDetector(
                        onTap: () => setModalState(() {
                          selected = amt;
                          ctrl.text = amt.toStringAsFixed(0);
                        }),
                        child: _PresetChip(
                            amount: amt, isSelected: isSelected),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Or enter amount',
                    style: TextStyle(
                        color: ctx.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixText: '₦ ',
                    hintText: 'Enter new monthly amount',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onChanged: (v) =>
                      setModalState(() => selected = double.tryParse(v)),
                ),
                const SizedBox(height: 20),
                Consumer(builder: (_, r, __) {
                  final isSaving =
                      r.watch(contributionPlanProvider).isSaving;
                  return PrimaryButton(
                    label: 'Confirm Increase',
                    width: double.infinity,
                    isLoading: isSaving,
                    onPressed: () async {
                            final amt = selected ??
                                double.tryParse(ctrl.text);
                            if (amt == null || amt <= 0) return;
                            Navigator.of(ctx).pop();
                            await r
                                .read(contributionPlanProvider
                                    .notifier)
                                .increaseContribution(amt);
                          },
                  );
                }),
              ],
            ),
          );
        });
      },
    );
  }

  List<double> _presetsAbove(double current) {
    final all = [5000.0, 10000.0, 20000.0, 50000.0, 100000.0];
    return all.where((a) => a > current).toList();
  }
}

// ---------------------------------------------------------------------------
// Request reduction action card
// ---------------------------------------------------------------------------
class _ReductionCard extends ConsumerWidget {
  final ContributionPlan? plan;
  const _ReductionCard({this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPending = plan?.pendingReduction != null;
    final loanState = ref.watch(loanProvider);
    final hasActiveLoan = loanState.loans
        .any((l) => l.status == 'active' || l.status == 'repaying');

    return _ActionCard(
      icon: Icons.trending_down,
      iconColor: hasPending || hasActiveLoan
          ? context.textSecondary
          : CoopvestColors.error,
      title: 'Request Reduction',
      subtitle: hasPending
          ? 'You already have a pending reduction request.'
          : hasActiveLoan
              ? 'Not available while you have an active loan.'
              : '3-month notice required. Min. ₦5,000.',
      badgeText: '3-Month Notice',
      badgeColor: CoopvestColors.warning,
      isDisabled: hasPending || hasActiveLoan,
      onTap: () => _showReductionSheet(context, ref),
    );
  }

  void _showReductionSheet(BuildContext context, WidgetRef ref) {
    final current = plan?.currentMonthlyAmount ?? 5000.0;
    final ctrl = TextEditingController();
    double? selected;
    final presets = _presetsBelow(current);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return _BottomSheetContainer(
            title: 'Request Contribution Reduction',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CoopvestColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: CoopvestColors.warning.withOpacity(0.4)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.schedule,
                          color: CoopvestColors.warning, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This request will take effect after a 3-month notice period. Your current contribution continues until then.',
                          style: TextStyle(
                              color: CoopvestColors.warning,
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Current: ₦${current.formatNumber()} / month',
                  style: TextStyle(
                      color: ctx.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (presets.isNotEmpty) ...[
                  Text('Quick Select',
                      style: TextStyle(
                          color: ctx.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: presets.map((amt) {
                      final isSelected = selected == amt;
                      return GestureDetector(
                        onTap: () => setModalState(() {
                          selected = amt;
                          ctrl.text = amt.toStringAsFixed(0);
                        }),
                        child: _PresetChip(
                            amount: amt, isSelected: isSelected),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Or enter amount (min ₦5,000)',
                    style: TextStyle(
                        color: ctx.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixText: '₦ ',
                    hintText: 'Enter new monthly amount',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onChanged: (v) =>
                      setModalState(() => selected = double.tryParse(v)),
                ),
                const SizedBox(height: 20),
                Consumer(builder: (_, r, __) {
                  final isSaving =
                      r.watch(contributionPlanProvider).isSaving;
                  return PrimaryButton(
                    label: 'Submit Reduction Request',
                    width: double.infinity,
                    isLoading: isSaving,
                    onPressed: () async {
                            final amt = selected ??
                                double.tryParse(ctrl.text);
                            if (amt == null || amt <= 0) return;
                            Navigator.of(ctx).pop();
                            await r
                                .read(contributionPlanProvider
                                    .notifier)
                                .requestReduction(amt);
                          },
                  );
                }),
              ],
            ),
          );
        });
      },
    );
  }

  List<double> _presetsBelow(double current) {
    const all = [5000.0, 10000.0, 20000.0, 50000.0];
    return all.where((a) => a < current).toList();
  }
}

// ---------------------------------------------------------------------------
// Shared UI components
// ---------------------------------------------------------------------------

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final bool isDisabled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                          color: context.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDisabled)
                Icon(Icons.chevron_right,
                    color: context.textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final double amount;
  final bool isSelected;
  const _PresetChip({required this.amount, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? CoopvestColors.primary
            : context.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isSelected
                ? CoopvestColors.primary
                : context.dividerColor),
      ),
      child: Text(
        '₦${amount.formatNumber()}',
        style: TextStyle(
          color: isSelected ? Colors.white : context.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _BottomSheetContainer extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheetContainer(
      {required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.scaffoldBackground,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
