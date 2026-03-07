import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../data/models/guarantor_models.dart';
import '../../../presentation/providers/guarantor_provider.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/loading.dart';

/// Guarantor Dashboard Screen - Track pending guarantor requests
class GuarantorDashboardScreen extends ConsumerStatefulWidget {
  const GuarantorDashboardScreen({super.key});

  @override
  ConsumerState<GuarantorDashboardScreen> createState() =>
      _GuarantorDashboardScreenState();
}

class _GuarantorDashboardScreenState
    extends ConsumerState<GuarantorDashboardScreen> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(guarantorProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guarantorProvider);
    final stats = state.stats;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Guarantor Management'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Stats Cards
          _buildStatsCards(stats),
          // Tab Bar
          _buildTabBar(),
          // Tab Content
          Expanded(
            child: state.isLoading
                ? const LoadingWidget()
                : _buildTabContent(state),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(GuarantorStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Pending',
              stats.pendingRequests.toString(),
              CoopvestColors.warning,
              Icons.pending_actions,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Accepted',
              stats.acceptedGuarantees.toString(),
              CoopvestColors.success,
              Icons.check_circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Amount',
              '₦${(stats.totalGuaranteedAmount / 1000).formatNumber()}k',
              CoopvestColors.primary,
              Icons.attach_money,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Pending Requests', 'My Guarantees', 'History'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = _currentTab == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? CoopvestColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : context.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(GuarantorState state) {
    switch (_currentTab) {
      case 0:
        return _buildPendingRequests(state.pendingRequests);
      case 1:
        return _buildMyGuarantees(state.myGuarantees);
      case 2:
        return _buildHistory(state.allRequests);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPendingRequests(List<GuarantorRequest> requests) {
    if (requests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.pending_actions,
        title: 'No Pending Requests',
        subtitle: 'You have no guarantor requests to review',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(GuarantorRequest request) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CoopvestColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.loanType.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: CoopvestColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (request.isExpired)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: CoopvestColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'EXPIRED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: CoopvestColors.error,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Member Info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: CoopvestColors.primary.withOpacity(0.1),
                  child: Text(
                    _getInitials(request.memberName),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: CoopvestColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.memberName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Member ID: ${request.memberId.substring(0, 8)}',
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
            const SizedBox(height: 16),
            // Loan Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.secondaryCardBackground.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Loan Amount',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textSecondary,
                          ),
                        ),
                        Text(
                          '₦${request.loanAmount.formatNumber()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: context.dividerColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guarantors',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textSecondary,
                          ),
                        ),
                        Text(
                          '${request.currentGuarantors}/${request.requiredGuarantors}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: request.progress,
                minHeight: 6,
                backgroundColor: CoopvestColors.primary.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation(CoopvestColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            // Action Buttons
            if (!request.isExpired)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDeclineDialog(request),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CoopvestColors.error,
                        side: const BorderSide(color: CoopvestColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAcceptDialog(request),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CoopvestColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyGuarantees(List<GuaranteedLoan> guarantees) {
    if (guarantees.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shield_outlined,
        title: 'No Guarantees',
        subtitle: "You haven't guaranteed any loans yet",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: guarantees.length,
      itemBuilder: (context, index) {
        final guarantee = guarantees[index];
        return _buildGuaranteeCard(guarantee);
      },
    );
  }

  Widget _buildGuaranteeCard(GuaranteedLoan guarantee) {
    final statusColor = guarantee.status == 'active'
        ? CoopvestColors.success
        : guarantee.status == 'completed'
            ? CoopvestColors.primary
            : CoopvestColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                guarantee.status == 'active'
                    ? Icons.shield
                    : guarantee.status == 'completed'
                        ? Icons.check_circle
                        : Icons.error,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guarantee.loanType,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For: ${guarantee.borrowerName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₦${guarantee.loanAmount.formatNumber()}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    guarantee.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(List<GuarantorRequest> requests) {
    final declined = requests.where((r) => r.status == 'declined').toList();
    final expired = requests.where((r) => r.status == 'expired').toList();

    if (requests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No History',
        subtitle: 'Your guarantor request history will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: declined.length + expired.length,
      itemBuilder: (context, index) {
        final allHistory = [...declined, ...expired];
        final request = allHistory[index];
        return _buildHistoryCard(request);
      },
    );
  }

  Widget _buildHistoryCard(GuarantorRequest request) {
    final isDeclined = request.status == 'declined';
    final color = isDeclined ? CoopvestColors.error : CoopvestColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
              isDeclined ? Icons.cancel : Icons.timer_off,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.loanType,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₦${request.loanAmount.formatNumber()} - ${request.memberName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              request.status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: context.textSecondary, size: 64),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: context.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  void _showAcceptDialog(GuarantorRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBackground,
        title: Text('Accept as Guarantor', style: TextStyle(color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to guarantee ${request.memberName}\'s loan of ₦${request.loanAmount.formatNumber()}?',
              style: TextStyle(color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CoopvestColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: CoopvestColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'By accepting, you agree to be liable for this loan if the borrower defaults.',
                      style: TextStyle(fontSize: 13, color: context.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success =
                  await ref.read(guarantorProvider.notifier).acceptRequest(request.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Successfully accepted as guarantor'),
                    backgroundColor: CoopvestColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CoopvestColors.success,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showDeclineDialog(GuarantorRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBackground,
        title: Text('Decline Request', style: TextStyle(color: context.textPrimary)),
        content: Text(
          'Are you sure you want to decline being a guarantor for ${request.memberName}?',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Request'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await ref
                  .read(guarantorProvider.notifier)
                  .declineRequest(request.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Request declined'),
                    backgroundColor: CoopvestColors.primary,
                  ),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: CoopvestColors.error,
              side: const BorderSide(color: CoopvestColors.error),
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }
}
