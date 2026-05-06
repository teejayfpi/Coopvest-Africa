import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../data/models/contributions/monthly_contribution.dart';
import '../../../presentation/providers/contributions/contribution_provider.dart';

/// Contribution Detail Screen
/// Shows full details of a single contribution including transaction breakdown,
/// status history, processing logs, and audit trail
class ContributionDetailScreen extends ConsumerStatefulWidget {
  final String contributionId;

  const ContributionDetailScreen({
    super.key,
    required this.contributionId,
  });

  @override
  ConsumerState<ContributionDetailScreen> createState() =>
      _ContributionDetailScreenState();
}

class _ContributionDetailScreenState extends ConsumerState<ContributionDetailScreen> {
  bool _isLoadingReceipt = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    await ref
        .read(contributionProvider.notifier)
        .loadContributionDetail(widget.contributionId);
  }

  Future<void> _downloadReceipt() async {
    setState(() => _isLoadingReceipt = true);
    try {
      final state = ref.read(contributionProvider);
      final receiptUrl = state.selectedDetail?.receiptUrl;
      if (receiptUrl != null && receiptUrl.isNotEmpty) {
        // In a real app, this would open the receipt URL
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt downloaded successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt not available')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download receipt: $e')),
      );
    } finally {
      setState(() => _isLoadingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contributionProvider);
    final detail = state.selectedDetail;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        color: CoopvestColors.primary,
        child: _buildBody(state),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: CoopvestColors.primary,
      elevation: 0,
      title: const Text(
        'Contribution Details',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: _isLoadingReceipt
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download, color: Colors.white),
          onPressed: _isLoadingReceipt ? null : _downloadReceipt,
        ),
      ],
    );
  }

  Widget _buildBody(ContributionState state) {
    if (state.isLoading && state.selectedDetail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.selectedDetail == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: CoopvestColors.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text('Failed to load contribution details'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final contribution = state.selectedDetail!.contribution;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header
          _buildStatusHeader(context, contribution),
          const SizedBox(height: 16),

          // Amount Card
          _buildAmountCard(context, contribution),
          const SizedBox(height: 16),

          // Transaction Reference
          if (contribution.transactionReference != null)
            _buildReferenceCard(context, contribution),
          const SizedBox(height: 16),

          // Payment Details
          _buildPaymentDetailsSection(context, contribution),
          const SizedBox(height: 16),

          // Status History
          if (state.selectedDetail!.contribution.statusHistory != null &&
              state.selectedDetail!.contribution.statusHistory!.isNotEmpty)
            _buildStatusHistorySection(
                context, state.selectedDetail!.contribution.statusHistory!),
          const SizedBox(height: 16),

          // Processing Logs
          if (state.selectedDetail!.processingLogs != null &&
              state.selectedDetail!.processingLogs!.isNotEmpty)
            _buildProcessingLogsSection(
                context, state.selectedDetail!.processingLogs!),
          const SizedBox(height: 16),

          // Audit Trail
          if (state.selectedDetail!.auditTrailId != null)
            _buildAuditTrailSection(context, state.selectedDetail!.auditTrailId!),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, MonthlyContribution contribution) {
    final statusColor = _getStatusColor(contribution.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.8),
            statusColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getStatusIcon(contribution.status),
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contribution.status.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contribution.type.displayName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context, MonthlyContribution contribution) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Contribution Amount',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'N${contribution.amount.formatNumber()}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: CoopvestColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: CoopvestColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'N${(contribution.amount).formatNumber()} received',
                style: const TextStyle(
                  color: CoopvestColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceCard(
      BuildContext context, MonthlyContribution contribution) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CoopvestColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.receipt_long,
                color: CoopvestColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Reference',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  Text(
                    contribution.transactionReference!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.copy,
                color: context.textSecondary,
              ),
              onPressed: () {
                // Copy to clipboard
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reference copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsSection(
      BuildContext context, MonthlyContribution contribution) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              context,
              'Payment Method',
              contribution.paymentMethod ?? 'N/A',
              Icons.payment,
            ),
            _buildDetailRow(
              context,
              'Source',
              contribution.sourceBank ?? contribution.sourceWallet ?? 'N/A',
              Icons.account_balance,
            ),
            if (contribution.postedDate != null)
              _buildDetailRow(
                context,
                'Posted Date',
                DateFormat('MMM dd, yyyy').format(contribution.postedDate!),
                Icons.event,
              ),
            if (contribution.processedDate != null)
              _buildDetailRow(
                context,
                'Processed Date',
                DateFormat('MMM dd, yyyy HH:mm').format(contribution.processedDate!),
                Icons.schedule,
              ),
            _buildDetailRow(
              context,
              'Created',
              DateFormat('MMM dd, yyyy HH:mm').format(contribution.createdAt),
              Icons.add_circle,
            ),
            _buildDetailRow(
              context,
              'Last Updated',
              DateFormat('MMM dd, yyyy HH:mm').format(contribution.updatedAt),
              Icons.update,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CoopvestColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: CoopvestColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHistorySection(
    BuildContext context,
    List<StatusHistory> history,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: CoopvestColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...history.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == history.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(item.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 40,
                          color: _getStatusColor(item.status).withOpacity(0.3),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.status.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(item.status),
                            ),
                          ),
                          if (item.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.description!,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy HH:mm')
                                .format(item.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingLogsSection(
    BuildContext context,
    List<ProcessingLog> logs,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.list_alt,
                  color: CoopvestColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Processing Logs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...logs.map((log) => _buildProcessingLogItem(context, log)),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingLogItem(BuildContext context, ProcessingLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.scaffoldBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.dividerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: log.success
                      ? CoopvestColors.success.withOpacity(0.1)
                      : CoopvestColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.step,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: log.success
                        ? CoopvestColors.success
                        : CoopvestColors.error,
                  ),
                ),
              ),
              Text(
                log.success ? 'SUCCESS' : 'FAILED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: log.success
                      ? CoopvestColors.success
                      : CoopvestColors.error,
                ),
              ),
            ],
          ),
          if (log.description != null) ...[
            const SizedBox(height: 8),
            Text(
              log.description!,
              style: TextStyle(
                fontSize: 13,
                color: context.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM dd, yyyy HH:mm:ss').format(log.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: context.textSecondary.withOpacity(0.7),
            ),
          ),
          if (log.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CoopvestColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: CoopvestColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditTrailSection(BuildContext context, String auditTrailId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CoopvestColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.verified_user,
                color: CoopvestColors.info,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audit Trail Reference',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  Text(
                    auditTrailId,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.content_copy,
                color: context.textSecondary,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audit reference copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ContributionStatus status) {
    switch (status) {
      case ContributionStatus.successful:
        return CoopvestColors.success;
      case ContributionStatus.pending:
        return CoopvestColors.warning;
      case ContributionStatus.failed:
        return CoopvestColors.error;
      case ContributionStatus.processing:
        return CoopvestColors.info;
      case ContributionStatus.reversed:
      case ContributionStatus.adjusted:
        return CoopvestColors.warning;
      case ContributionStatus.disputed:
        return CoopvestColors.error;
    }
  }

  IconData _getStatusIcon(ContributionStatus status) {
    switch (status) {
      case ContributionStatus.successful:
        return Icons.check_circle;
      case ContributionStatus.pending:
        return Icons.pending;
      case ContributionStatus.failed:
        return Icons.cancel;
      case ContributionStatus.processing:
        return Icons.sync;
      case ContributionStatus.reversed:
        return Icons.undo;
      case ContributionStatus.adjusted:
        return Icons.edit;
      case ContributionStatus.disputed:
        return Icons.report_problem;
    }
  }
}
