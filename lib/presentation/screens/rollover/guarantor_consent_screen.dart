import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/rollover_models.dart';
import '../../providers/rollover_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/cards.dart';
import '../../widgets/rollover/rollover_common_widgets.dart';

/// Guarantor Consent Tracker — borrower's view showing each guarantor's status.
/// Declined guarantors can be replaced using the replace sheet.
class GuarantorConsentScreen extends ConsumerStatefulWidget {
  final String rolloverId;
  const GuarantorConsentScreen({super.key, required this.rolloverId});

  @override
  ConsumerState<GuarantorConsentScreen> createState() =>
      _GuarantorConsentScreenState();
}

class _GuarantorConsentScreenState
    extends ConsumerState<GuarantorConsentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(rolloverProvider.notifier)
          .getRolloverGuarantors(rolloverId: widget.rolloverId);
    });
  }

  Future<void> _showReplaceSheet(
      BuildContext context, RolloverGuarantor guarantor) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final idCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Replace ${guarantor.guarantorName}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter the details of the new guarantor.',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idCtrl,
                decoration: InputDecoration(
                  labelText: 'Member ID',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty ||
                            phoneCtrl.text.isEmpty ||
                            idCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in all fields'),
                              backgroundColor: CoopvestColors.error,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        final success = await ref
                            .read(rolloverProvider.notifier)
                            .replaceGuarantor(
                              rolloverId: widget.rolloverId,
                              oldGuarantorId: guarantor.guarantorId,
                              newGuarantorId: idCtrl.text.trim(),
                              newGuarantorName: nameCtrl.text.trim(),
                              newGuarantorPhone: phoneCtrl.text.trim(),
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Guarantor replaced successfully'
                                  : ref.read(rolloverProvider).error ??
                                      'Failed to replace guarantor'),
                              backgroundColor: success
                                  ? CoopvestColors.success
                                  : CoopvestColors.error,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CoopvestColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rolloverProvider);
    final rollover = state.currentRollover;
    final guarantors = state.guarantors;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Guarantor Consent',
          style: TextStyle(
              color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.iconPrimary),
            onPressed: () => ref
                .read(rolloverProvider.notifier)
                .getRolloverGuarantors(rolloverId: widget.rolloverId),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref
            .read(rolloverProvider.notifier)
            .getRolloverGuarantors(rolloverId: widget.rolloverId),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rollover != null) RolloverSummaryCard(rollover: rollover),
              const SizedBox(height: 24),
              _buildConsentProgress(context, guarantors),
              const SizedBox(height: 24),
              _buildGuarantorList(context, guarantors),
              const SizedBox(height: 24),
              _buildNextSteps(context, guarantors),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentProgress(
      BuildContext context, List<RolloverGuarantor> guarantors) {
    final total = guarantors.length;
    final accepted = guarantors
        .where((g) => g.status == GuarantorConsentStatus.accepted)
        .length;
    final declined = guarantors
        .where((g) => g.status == GuarantorConsentStatus.declined)
        .length;
    final pending = total - accepted - declined;
    final progress = total > 0 ? (accepted / total).toDouble() : 0.0;

    return AppCard(
      backgroundColor: context.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consent Progress',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary),
              ),
              Text(
                '$accepted / $total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: accepted == total
                      ? CoopvestColors.success
                      : CoopvestColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: context.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                declined > 0 ? CoopvestColors.error : CoopvestColors.success,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _dot(CoopvestColors.success, 'Accepted: $accepted'),
              const SizedBox(width: 16),
              _dot(CoopvestColors.error, 'Declined: $declined'),
              const SizedBox(width: 16),
              _dot(context.textSecondary, 'Pending: $pending'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
      ],
    );
  }

  Widget _buildGuarantorList(
      BuildContext context, List<RolloverGuarantor> guarantors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guarantors',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'All guarantors must provide fresh consent for this rollover.',
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        const SizedBox(height: 12),
        ...guarantors.map(
          (g) => GuarantorDetailCard(
            guarantor: g,
            showActions: g.status == GuarantorConsentStatus.declined,
            onReplace: () => _showReplaceSheet(context, g),
          ),
        ),
      ],
    );
  }

  Widget _buildNextSteps(
      BuildContext context, List<RolloverGuarantor> guarantors) {
    final accepted = guarantors
        .where((g) => g.status == GuarantorConsentStatus.accepted)
        .length;
    final declined = guarantors
        .where((g) => g.status == GuarantorConsentStatus.declined)
        .length;

    if (declined > 0) {
      return AppCard(
        backgroundColor: CoopvestColors.error.withOpacity(0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: CoopvestColors.error),
                SizedBox(width: 8),
                Text(
                  'Action Required',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CoopvestColors.error),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$declined guarantor(s) have declined. Tap "Replace" on each card above to appoint a new guarantor.',
              style: TextStyle(fontSize: 13, color: context.textPrimary),
            ),
          ],
        ),
      );
    }

    if (accepted == 3) {
      return AppCard(
        backgroundColor: CoopvestColors.success.withOpacity(0.1),
        child: Column(
          children: [
            const Icon(Icons.check_circle,
                color: CoopvestColors.success, size: 48),
            const SizedBox(height: 12),
            Text(
              'All Guarantors Have Consented',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Your rollover request is now pending admin approval.',
              style:
                  TextStyle(fontSize: 13, color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return AppCard(
      backgroundColor: context.cardBackground,
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, color: context.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${3 - accepted} guarantor(s) still need to respond. They will receive a notification to review and accept.',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guarantor detail card ─────────────────────────────────────────────────────

class GuarantorDetailCard extends StatelessWidget {
  final RolloverGuarantor guarantor;
  final bool showActions;
  final VoidCallback? onReplace;

  const GuarantorDetailCard({
    super.key,
    required this.guarantor,
    this.showActions = false,
    this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: context.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: CoopvestColors.primary.withOpacity(0.1),
                child: Text(
                  guarantor.guarantorName.isNotEmpty
                      ? guarantor.guarantorName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: CoopvestColors.primary,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guarantor.guarantorName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary),
                    ),
                    Text(
                      guarantor.guarantorPhone,
                      style: TextStyle(
                          fontSize: 12, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              _statusBadge(guarantor.status),
            ],
          ),
          if (showActions && onReplace != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReplace,
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Replace Guarantor'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CoopvestColors.primary,
                  side: const BorderSide(color: CoopvestColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(GuarantorConsentStatus status) {
    Color color;
    String label;
    switch (status) {
      case GuarantorConsentStatus.accepted:
        color = CoopvestColors.success;
        label = 'Accepted';
        break;
      case GuarantorConsentStatus.declined:
        color = CoopvestColors.error;
        label = 'Declined';
        break;
      case GuarantorConsentStatus.expired:
        color = Colors.grey;
        label = 'Expired';
        break;
      case GuarantorConsentStatus.invited:
        color = CoopvestColors.primary;
        label = 'Invited';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
