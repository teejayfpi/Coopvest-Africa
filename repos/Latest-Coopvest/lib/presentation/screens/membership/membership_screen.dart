import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/termination_models.dart';
import '../../../data/models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/termination_provider.dart';
import '../../widgets/common/buttons.dart';
import 'termination_info_screen.dart';
import 'package:intl/intl.dart';

/// Membership Screen
/// Shows membership status and provides access to termination workflow
/// Location: Profile → Account Settings → Membership
class MembershipScreen extends ConsumerWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final terminationState = ref.watch(terminationProvider);
    final user = authState.user;
    final membershipStatus = user?.membershipStatus ?? 'active';
    final currentRequest = terminationState.currentRequest;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Membership'),
        backgroundColor: CoopvestColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Membership Status Card
            _buildMembershipStatusCard(context, membershipStatus, currentRequest),
            const SizedBox(height: 24),

            // Membership Information Section
            _buildMembershipInfoSection(user, context),
            const SizedBox(height: 24),

            // Termination Section - Always show for active members
            if (membershipStatus == 'active') ...[
              _buildTerminationSection(context, ref, terminationState),
            ],

            // Pending Termination Info (shown if request is pending)
            if (currentRequest != null && currentRequest!.isPending) ...[
              _buildPendingTerminationInfo(context, ref, currentRequest!),
            ],

            const SizedBox(height: 24),

            // Terms and Conditions
            _buildTermsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipStatusCard(
    BuildContext context,
    String membershipStatus,
    TerminationRequest? currentRequest,
  ) {
    final statusText = getMembershipStatusText(membershipStatus);
    final isActive = membershipStatus == 'active';
    final isPending = membershipStatus == 'pending_termination';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CoopvestColors.primary,
            CoopvestColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CoopvestColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive
                    ? Icons.verified_user
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Membership Status',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.hourglass_empty,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Pending Approval',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatusDetail(
                icon: Icons.account_balance,
                label: 'Full Access',
                value: isActive ? 'Active' : 'Restricted',
              ),
              const SizedBox(width: 24),
              _buildStatusDetail(
                icon: Icons.savings,
                label: 'Services',
                value: isActive ? 'Available' : 'Suspended',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDetail({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipInfoSection(User? user, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Membership Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildInfoRow(
                context: context,
                icon: Icons.calendar_today,
                label: 'Member Since',
                value: user?.createdAt != null
                    ? _formatDate(user!.createdAt)
                    : 'N/A',
              ),
              const Divider(height: 1),
              _buildInfoRow(
                context: context,
                icon: Icons.verified,
                label: 'KYC Status',
                value: (user?.kycStatus ?? '').toUpperCase(),
              ),
              const Divider(height: 1),
              _buildInfoRow(
                context: context,
                icon: Icons.shield,
                label: 'Membership ID',
                value: user?.id != null && user!.id.length >= 8 
                    ? user.id.substring(0, 8).toUpperCase() 
                    : 'N/A',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: CoopvestColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminationSection(
    BuildContext context,
    WidgetRef ref,
    TerminationState terminationState,
  ) {
    final isLoading = terminationState.isLoading;
    final eligibility = terminationState.eligibility;
    final isEligible = eligibility?.isEligible ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Membership Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.info_outline,
                  color: CoopvestColors.info,
                ),
                title: const Text(
                  'Terminate Membership',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: CoopvestColors.error,
                  ),
                ),
                subtitle: const Text(
                  'Request to close your membership',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            CoopvestColors.primary.withOpacity(0.7),
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.chevron_right,
                        color: CoopvestColors.lightGray,
                      ),
                onTap: isLoading
                    ? null
                    : () {
                        _showLoadingDialog(context);
                        ref
                            .read(terminationProvider.notifier)
                            .checkEligibility()
                            .then((eligibility) {
                          Navigator.of(context).pop(); // Close loading dialog
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TerminationInfoScreen(),
                              ),
                            );
                          }
                        }).catchError((error) {
                          Navigator.of(context).pop(); // Close loading dialog
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $error'),
                                backgroundColor: CoopvestColors.error,
                              ),
                            );
                          }
                        });
                      },
              ),
            ],
          ),
        ),
        if (eligibility != null && !isEligible) ...[
          const SizedBox(height: 12),
          _buildEligibilityWarnings(eligibility, context),
        ],
      ],
    );
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      CoopvestColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Checking Eligibility',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we verify your account...',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEligibilityWarnings(TerminationEligibility eligibility, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CoopvestColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CoopvestColors.warning.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning, color: CoopvestColors.warning, size: 18),
              SizedBox(width: 8),
              Text(
                'Termination Not Available',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: CoopvestColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...eligibility.eligibilityErrors.map(
            (error) => Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 4),
              child: Text(
                '• $error',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTerminationInfo(
    BuildContext context,
    WidgetRef ref,
    TerminationRequest request,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Termination Request',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CoopvestColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CoopvestColors.warning.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.hourglass_empty,
                    color: CoopvestColors.warning,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your termination request is pending admin approval',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: CoopvestColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailRow(context, 
                'Requested On',
                _formatDate(request.requestedAt),
              ),
              _buildDetailRow(context, 
                'Reason',
                getTerminationReasonText(request.reason),
              ),
              _buildDetailRow(context, 
                'Exit Type',
                request.exitType == TerminationExitType.permanent
                    ? 'Permanent'
                    : 'Temporary',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showCancelDialog(context, ref, request.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CoopvestColors.error,
                    side: const BorderSide(color: CoopvestColors.error),
                  ),
                  child: const Text('Cancel Request'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.secondaryCardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Membership termination is subject to approval and may take 7-14 business days. All financial obligations must be settled before termination can be processed.',
            style: TextStyle(
              fontSize: 11,
              color: context.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              // Navigate to terms
            },
            child: const Text(
              'View Terms & Conditions',
              style: TextStyle(
                fontSize: 12,
                color: CoopvestColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Termination Request'),
        content: const Text(
          'Are you sure you want to cancel your termination request? '
          'You can submit a new request at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Request'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(terminationProvider.notifier)
                  .cancelRequest(requestId: requestId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Termination request cancelled'),
                    backgroundColor: CoopvestColors.success,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: CoopvestColors.error,
            ),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
  }

  String getMembershipStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'pending_termination':
        return 'Pending Termination';
      case 'suspended':
        return 'Suspended';
      case 'terminated':
        return 'Terminated';
      case 'inactive':
        return 'Inactive';
      default:
        return status.toUpperCase();
    }
  }
}