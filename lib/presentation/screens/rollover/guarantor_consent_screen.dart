import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/rollover_models.dart';
import '../../providers/rollover_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/cards.dart';
import '../../widgets/rollover/rollover_common_widgets.dart';

/// Guarantor Consent Screen
class GuarantorConsentScreen extends ConsumerWidget {
  final String rolloverId;
  const GuarantorConsentScreen({super.key, required this.rolloverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rolloverProvider);
    final rollover = state.currentRollover;
    final guarantors = state.guarantors;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: Text('Guarantor Consent', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [IconButton(icon: Icon(Icons.refresh, color: context.iconPrimary), onPressed: () => ref.read(rolloverProvider.notifier).getRolloverGuarantors(rolloverId: rolloverId))],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await ref.read(rolloverProvider.notifier).getRolloverGuarantors(rolloverId: rolloverId),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rollover != null) RolloverSummaryCard(rollover: rollover),
              const SizedBox(height: 24),
              _buildConsentProgress(context, guarantors),
              const SizedBox(height: 24),
              _buildGuarantorList(context, guarantors, ref),
              const SizedBox(height: 24),
              _buildNextSteps(context, guarantors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentProgress(BuildContext context, List<RolloverGuarantor> guarantors) {
    final total = guarantors.length;
    final accepted = guarantors.where((g) => g.status == GuarantorConsentStatus.accepted).length;
    final declined = guarantors.where((g) => g.status == GuarantorConsentStatus.declined).length;
    final pending = total - accepted - declined;
    final progress = total > 0 ? (accepted / total).toDouble() : 0.0;

    return AppCard(
      backgroundColor: context.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Guarantor Consent Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)), Text('$accepted / $total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accepted == total ? CoopvestColors.success : CoopvestColors.primary))]),
          const SizedBox(height: 16),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 12, backgroundColor: context.dividerColor, valueColor: AlwaysStoppedAnimation<Color>(declined > 0 ? CoopvestColors.error : CoopvestColors.success))),
          const SizedBox(height: 12),
          Row(children: [_buildStatusIndicator(context, CoopvestColors.success, 'Accepted: $accepted'), const SizedBox(width: 16), _buildStatusIndicator(context, CoopvestColors.error, 'Declined: $declined'), const SizedBox(width: 16), _buildStatusIndicator(context, context.textSecondary, 'Pending: $pending')]),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary))]);
  }

  Widget _buildGuarantorList(BuildContext context, List<RolloverGuarantor> guarantors, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Guarantors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
        const SizedBox(height: 8),
        Text('All guarantors must provide fresh consent for this rollover.', style: TextStyle(fontSize: 12, color: context.textSecondary)),
        const SizedBox(height: 12),
        ...guarantors.map((guarantor) => GuarantorDetailCard(guarantor: guarantor, showActions: guarantor.status == GuarantorConsentStatus.declined, onReplace: () {})),
      ],
    );
  }

  Widget _buildNextSteps(BuildContext context, List<RolloverGuarantor> guarantors) {
    final accepted = guarantors.where((g) => g.status == GuarantorConsentStatus.accepted).length;
    final declined = guarantors.where((g) => g.status == GuarantorConsentStatus.declined).length;

    if (declined > 0) {
      return AppCard(backgroundColor: CoopvestColors.error.withOpacity(0.1), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.warning, color: CoopvestColors.error), SizedBox(width: 8), Text('Action Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CoopvestColors.error))]), const SizedBox(height: 12), Text('$declined guarantor(s) have declined. You must replace them.', style: TextStyle(fontSize: 13, color: context.textPrimary)), const SizedBox(height: 16), PrimaryButton(label: 'Replace Declined Guarantors', onPressed: () {})]));
    }
    if (accepted == 3) {
      return AppCard(backgroundColor: CoopvestColors.success.withOpacity(0.1), child: Column(children: [const Icon(Icons.check_circle, color: CoopvestColors.success, size: 48), const SizedBox(height: 12), Text('All Guarantors Have Consented', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)), const SizedBox(height: 8), Text('Your rollover request is now pending admin approval.', style: TextStyle(fontSize: 13, color: context.textSecondary), textAlign: TextAlign.center)]));
    }
    return AppCard(backgroundColor: context.cardBackground, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.hourglass_empty, color: context.textSecondary), const SizedBox(width: 8), Text('Awaiting Responses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary))]), const SizedBox(height: 12), Text('${3 - accepted} guarantor(s) still need to respond.', style: TextStyle(fontSize: 13, color: context.textSecondary))]));
  }
}

class GuarantorDetailCard extends StatelessWidget {
  final RolloverGuarantor guarantor;
  final bool showActions;
  final VoidCallback? onReplace;
  const GuarantorDetailCard({super.key, required this.guarantor, this.showActions = false, this.onReplace});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: context.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: CoopvestColors.primary.withOpacity(0.1), child: Text(guarantor.name[0], style: const TextStyle(color: CoopvestColors.primary, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(guarantor.name, style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)), Text(guarantor.phone, style: TextStyle(fontSize: 12, color: context.textSecondary))])),
          _buildStatusBadge(guarantor.status),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(GuarantorConsentStatus status) {
    Color color;
    String label;
    switch (status) {
      case GuarantorConsentStatus.accepted: color = CoopvestColors.success; label = 'Accepted'; break;
      case GuarantorConsentStatus.declined: color = CoopvestColors.error; label = 'Declined'; break;
      case GuarantorConsentStatus.pending: color = Colors.orange; label = 'Pending'; break;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  }
}
