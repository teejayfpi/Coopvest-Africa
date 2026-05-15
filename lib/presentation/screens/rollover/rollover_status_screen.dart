import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/rollover_models.dart';
import '../../providers/rollover_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/cards.dart';
import '../../widgets/rollover/rollover_common_widgets.dart';

/// Full status/timeline view for a rollover request.
/// Shows current stage, guarantor progress, and admin decision.
class RolloverStatusScreen extends ConsumerStatefulWidget {
  final String rolloverId;
  const RolloverStatusScreen({super.key, required this.rolloverId});

  @override
  ConsumerState<RolloverStatusScreen> createState() =>
      _RolloverStatusScreenState();
}

class _RolloverStatusScreenState extends ConsumerState<RolloverStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(rolloverProvider.notifier);
      notifier.getRolloverDetails(rolloverId: widget.rolloverId);
      notifier.getRolloverGuarantors(rolloverId: widget.rolloverId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rolloverProvider);
    final rollover = state.currentRollover;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Rollover Status',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.iconPrimary),
            onPressed: () {
              ref.read(rolloverProvider.notifier)
                ..getRolloverDetails(rolloverId: widget.rolloverId)
                ..getRolloverGuarantors(rolloverId: widget.rolloverId);
            },
          ),
        ],
      ),
      body: state.isLoading && rollover == null
          ? const Center(child: CircularProgressIndicator())
          : rollover == null
              ? _buildEmpty(context)
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(rolloverProvider.notifier)
                        .getRolloverDetails(rolloverId: widget.rolloverId);
                    await ref
                        .read(rolloverProvider.notifier)
                        .getRolloverGuarantors(rolloverId: widget.rolloverId);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status banner
                        _buildStatusBanner(context, rollover),
                        const SizedBox(height: 20),

                        // Rollover summary
                        RolloverSummaryCard(rollover: rollover),
                        const SizedBox(height: 20),

                        // Timeline
                        _buildTimeline(context, rollover),
                        const SizedBox(height: 20),

                        // Guarantors progress
                        _buildGuarantorProgress(context, state.guarantors),
                        const SizedBox(height: 20),

                        // Admin decision (if finalised)
                        if (rollover.status == RolloverStatus.approved ||
                            rollover.status == RolloverStatus.rejected)
                          _buildAdminDecision(context, rollover),

                        // Cancel button (only while pending)
                        if (rollover.status == RolloverStatus.pending) ...[
                          const SizedBox(height: 8),
                          _buildCancelButton(context, rollover),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ── Status banner ──────────────────────────────────────────────────────────

  Widget _buildStatusBanner(BuildContext context, LoanRollover rollover) {
    final info = _statusInfo(rollover.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: info.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: info.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(info.icon, color: info.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: info.color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  info.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Timeline ───────────────────────────────────────────────────────────────

  Widget _buildTimeline(BuildContext context, LoanRollover rollover) {
    final steps = [
      _TimelineStep(
        label: 'Request Submitted',
        date: rollover.requestedAt,
        done: true,
        icon: Icons.send_rounded,
      ),
      _TimelineStep(
        label: 'Guarantor Consent',
        date: null,
        done: rollover.status == RolloverStatus.awaitingAdminApproval ||
            rollover.status == RolloverStatus.approved ||
            rollover.status == RolloverStatus.completed,
        active: rollover.status == RolloverStatus.pending,
        icon: Icons.people_outline_rounded,
      ),
      _TimelineStep(
        label: 'Admin Review',
        date: rollover.approvedAt ?? rollover.rejectedAt,
        done: rollover.status == RolloverStatus.approved ||
            rollover.status == RolloverStatus.completed,
        active: rollover.status == RolloverStatus.awaitingAdminApproval,
        failed: rollover.status == RolloverStatus.rejected,
        icon: Icons.admin_panel_settings_outlined,
      ),
      _TimelineStep(
        label: 'Rollover Completed',
        date: rollover.completedAt,
        done: rollover.status == RolloverStatus.completed,
        icon: Icons.check_circle_outline_rounded,
      ),
    ];

    return AppCard(
      backgroundColor: context.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            return _TimelineTile(
              step: step,
              isLast: i == steps.length - 1,
            );
          }),
        ],
      ),
    );
  }

  // ── Guarantor progress ─────────────────────────────────────────────────────

  Widget _buildGuarantorProgress(
      BuildContext context, List<RolloverGuarantor> guarantors) {
    if (guarantors.isEmpty) {
      return const SizedBox.shrink();
    }
    final accepted =
        guarantors.where((g) => g.status == GuarantorConsentStatus.accepted).length;
    final declined =
        guarantors.where((g) => g.status == GuarantorConsentStatus.declined).length;
    final pending = guarantors.length - accepted - declined;

    return AppCard(
      backgroundColor: context.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Guarantors',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              Text(
                '$accepted / ${guarantors.length} consented',
                style: TextStyle(
                  fontSize: 13,
                  color: accepted == guarantors.length
                      ? CoopvestColors.success
                      : context.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: guarantors.isNotEmpty ? accepted / guarantors.length : 0,
              minHeight: 8,
              backgroundColor: context.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                declined > 0 ? CoopvestColors.error : CoopvestColors.success,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...guarantors.map((g) => _GuarantorRow(guarantor: g)),
          const SizedBox(height: 4),
          Row(
            children: [
              _badge(CoopvestColors.success, 'Accepted $accepted'),
              const SizedBox(width: 10),
              _badge(CoopvestColors.error, 'Declined $declined'),
              const SizedBox(width: 10),
              _badge(Colors.orange, 'Pending $pending'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  // ── Admin decision ─────────────────────────────────────────────────────────

  Widget _buildAdminDecision(BuildContext context, LoanRollover rollover) {
    final approved = rollover.status == RolloverStatus.approved ||
        rollover.status == RolloverStatus.completed;
    final color = approved ? CoopvestColors.success : CoopvestColors.error;
    final icon =
        approved ? Icons.verified_outlined : Icons.cancel_outlined;

    return AppCard(
      backgroundColor: color.withOpacity(0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                approved ? 'Approved by Admin' : 'Rejected by Admin',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (rollover.adminNotes != null || rollover.rejectionReason != null) ...[
            const SizedBox(height: 10),
            Text(
              rollover.rejectionReason ?? rollover.adminNotes ?? '',
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Cancel button ──────────────────────────────────────────────────────────

  Widget _buildCancelButton(BuildContext context, LoanRollover rollover) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _confirmCancel(context, rollover.id),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: CoopvestColors.error),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Cancel Rollover Request',
          style: TextStyle(
            color: CoopvestColors.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, String rolloverId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Rollover?'),
        content: const Text(
            'Are you sure you want to cancel this rollover request? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: CoopvestColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final success = await ref
          .read(rolloverProvider.notifier)
          .cancelRollover(rolloverId: rolloverId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Rollover request cancelled'
                : ref.read(rolloverProvider).error ?? 'Failed to cancel'),
            backgroundColor:
                success ? CoopvestColors.success : CoopvestColors.error,
          ),
        );
        if (success) Navigator.of(context).pop();
      }
    }
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.find_in_page_outlined,
              size: 64, color: context.textSecondary),
          const SizedBox(height: 16),
          Text('Rollover not found',
              style: TextStyle(color: context.textSecondary)),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Go Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  _StatusInfo _statusInfo(RolloverStatus status) {
    switch (status) {
      case RolloverStatus.pending:
        return _StatusInfo(
          title: 'Awaiting Guarantor Consent',
          description: 'Waiting for all guarantors to respond.',
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange,
        );
      case RolloverStatus.awaitingAdminApproval:
        return _StatusInfo(
          title: 'Pending Admin Approval',
          description: 'All guarantors have consented. Admin review in progress.',
          icon: Icons.admin_panel_settings_outlined,
          color: CoopvestColors.primary,
        );
      case RolloverStatus.approved:
        return _StatusInfo(
          title: 'Approved',
          description: 'Your rollover has been approved. New loan terms are active.',
          icon: Icons.check_circle_outline_rounded,
          color: CoopvestColors.success,
        );
      case RolloverStatus.completed:
        return _StatusInfo(
          title: 'Completed',
          description: 'Rollover complete. Your new loan is now active.',
          icon: Icons.done_all_rounded,
          color: CoopvestColors.success,
        );
      case RolloverStatus.rejected:
        return _StatusInfo(
          title: 'Rejected',
          description: 'This rollover request was rejected by admin.',
          icon: Icons.cancel_outlined,
          color: CoopvestColors.error,
        );
      case RolloverStatus.cancelled:
        return _StatusInfo(
          title: 'Cancelled',
          description: 'This rollover request was cancelled.',
          icon: Icons.remove_circle_outline,
          color: Colors.grey,
        );
      default:
        return _StatusInfo(
          title: 'Processing',
          description: 'Your request is being processed.',
          icon: Icons.sync_rounded,
          color: Colors.blueGrey,
        );
    }
  }
}

// ── Timeline tile ────────────────────────────────────────────────────────────

class _TimelineStep {
  final String label;
  final DateTime? date;
  final bool done;
  final bool active;
  final bool failed;
  final IconData icon;

  _TimelineStep({
    required this.label,
    required this.date,
    required this.icon,
    this.done = false,
    this.active = false,
    this.failed = false,
  });
}

class _TimelineTile extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;
  const _TimelineTile({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    if (step.failed) {
      dotColor = CoopvestColors.error;
    } else if (step.done) {
      dotColor = CoopvestColors.success;
    } else if (step.active) {
      dotColor = CoopvestColors.primary;
    } else {
      dotColor = Colors.grey.shade300;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: dotColor.withOpacity(step.done || step.active || step.failed ? 1 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.failed
                        ? Icons.close
                        : step.done
                            ? Icons.check
                            : step.icon,
                    size: 16,
                    color: step.done || step.active || step.failed
                        ? Colors.white
                        : Colors.grey.shade400,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: step.done ? CoopvestColors.success.withOpacity(0.3) : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    step.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: step.done || step.active || step.failed
                          ? const Color(0xFF1B3A6B)
                          : Colors.grey.shade400,
                    ),
                  ),
                  if (step.date != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${step.date!.day}/${step.date!.month}/${step.date!.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guarantor row ────────────────────────────────────────────────────────────

class _GuarantorRow extends StatelessWidget {
  final RolloverGuarantor guarantor;
  const _GuarantorRow({required this.guarantor});

  @override
  Widget build(BuildContext context) {
    final statusColor = _color(guarantor.status);
    final statusLabel = _label(guarantor.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: CoopvestColors.primary.withOpacity(0.1),
            radius: 18,
            child: Text(
              guarantor.guarantorName.isNotEmpty
                  ? guarantor.guarantorName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: CoopvestColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guarantor.guarantorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  guarantor.guarantorPhone,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _color(GuarantorConsentStatus s) {
    switch (s) {
      case GuarantorConsentStatus.accepted:
        return CoopvestColors.success;
      case GuarantorConsentStatus.declined:
        return CoopvestColors.error;
      case GuarantorConsentStatus.expired:
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _label(GuarantorConsentStatus s) {
    switch (s) {
      case GuarantorConsentStatus.accepted:
        return 'Accepted';
      case GuarantorConsentStatus.declined:
        return 'Declined';
      case GuarantorConsentStatus.expired:
        return 'Expired';
      case GuarantorConsentStatus.invited:
        return 'Invited';
      default:
        return 'Pending';
    }
  }
}

// ── Status info helper ────────────────────────────────────────────────────────

class _StatusInfo {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  _StatusInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
