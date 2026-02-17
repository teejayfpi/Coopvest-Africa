import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../data/models/termination_models.dart';
import '../../providers/termination_provider.dart';
import '../../widgets/common/buttons.dart';
import 'termination_application_screen.dart';

/// Termination Information Screen
/// First screen in the termination workflow - shows disclosure and implications
/// Location: Profile → Account Settings → Membership → Terminate Membership
class TerminationInfoScreen extends ConsumerWidget {
  const TerminationInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminationState = ref.watch(terminationProvider);
    final eligibility = terminationState.eligibility;

    return Scaffold(
      backgroundColor: CoopvestColors.veryLightGray,
      appBar: AppBar(
        title: const Text('Terminate Membership'),
        backgroundColor: CoopvestColors.error,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Header
            _buildWarningHeader(),
            const SizedBox(height: 24),

            // Important Notice
            _buildImportantNotice(),
            const SizedBox(height: 24),

            // Eligibility Conditions
            if (eligibility != null) ...[
              _buildEligibilityStatus(context, eligibility),
              const SizedBox(height: 24),
            ],

            // Eligibility Requirements
            _buildEligibilityRequirements(),
            const SizedBox(height: 24),

            // Implications Section
            _buildImplicationsSection(),
            const SizedBox(height: 24),

            // Backend Authority Notice
            _buildBackendAuthorityNotice(),
            const SizedBox(height: 32),

            // Continue Button
            if (eligibility?.isEligible ?? true)
              PrimaryButton(
                label: 'Continue to Application',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TerminationApplicationScreen(),
                    ),
                  );
                },
                backgroundColor: CoopvestColors.error,
              )
            else
              SecondaryButton(
                label: 'Back to Membership',
                onPressed: () => Navigator.pop(context),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CoopvestColors.error,
            CoopvestColors.error.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: const [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'IMPORTANT - READ CAREFULLY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'You are about to request the termination of your Coopvest membership. This action has permanent consequences.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImportantNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info, color: CoopvestColors.info),
              SizedBox(width: 8),
              Text(
                'What This Means',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletPoint(
            'Your access to all Coopvest services will be revoked',
          ),
          _buildBulletPoint(
            'You will no longer be able to save, borrow, or invest',
          ),
          _buildBulletPoint(
            'Your membership benefits will be permanently terminated',
          ),
          _buildBulletPoint(
            'This action requires admin approval and cannot be undone instantly',
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityStatus(
    BuildContext context,
    TerminationEligibility eligibility,
  ) {
    final isEligible = eligibility.isEligible;
    final statusColor = isEligible ? CoopvestColors.success : CoopvestColors.error;
    final statusIcon = isEligible ? Icons.check_circle : Icons.cancel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEligible
            ? CoopvestColors.success.withAlpha((255 * 0.1).toInt())
            : CoopvestColors.error.withAlpha((255 * 0.1).toInt()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEligible
              ? CoopvestColors.success.withAlpha((255 * 0.3).toInt())
              : CoopvestColors.error.withAlpha((255 * 0.3).toInt()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEligible
                      ? 'You Are Eligible for Termination'
                      : 'Termination Not Available',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (!isEligible && eligibility.eligibilityErrors.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...eligibility.eligibilityErrors.map(
              (error) => Padding(
                padding: const EdgeInsets.only(left: 26, top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: CoopvestColors.error)),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CoopvestColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEligibilityRequirements() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_user, color: CoopvestColors.primary),
              SizedBox(width: 8),
              Text(
                'Eligibility Conditions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'To be eligible for membership termination, you must NOT have:',
            style: TextStyle(
              fontSize: 13,
              color: CoopvestColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildRequirementItem(
            icon: Icons.account_balance,
            text: 'Any outstanding loan balance',
            isRequired: false,
          ),
          _buildRequirementItem(
            icon: Icons.schedule,
            text: 'Any pending loan repayments',
            isRequired: false,
          ),
          _buildRequirementItem(
            icon: Icons.trending_up,
            text: 'Any active investments',
            isRequired: false,
          ),
          _buildRequirementItem(
            icon: Icons.lock,
            text: 'Any locked or restricted savings',
            isRequired: false,
          ),
          _buildRequirementItem(
            icon: Icons.handshake,
            text: 'Guarantor obligations for active loans',
            isRequired: false,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem({
    required IconData icon,
    required String text,
    required bool isRequired,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isRequired ? CoopvestColors.error : CoopvestColors.success,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: CoopvestColors.textPrimary,
              ),
            ),
          ),
          Icon(
            isRequired ? Icons.close : Icons.check,
            size: 16,
            color: isRequired ? CoopvestColors.error : CoopvestColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildImplicationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.gavel, color: CoopvestColors.primary),
              SizedBox(width: 8),
              Text(
                'Terms of Termination',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildImplicationItem(
            number: '1',
            title: 'Approval Required',
            description:
                'Your termination request will be reviewed by an admin. There is no automatic approval.',
          ),
          _buildImplicationItem(
            number: '2',
            title: 'Financial Settlement',
            description:
                'All financial obligations must be settled before termination can be processed.',
          ),
          _buildImplicationItem(
            number: '3',
            title: 'Guarantor Release',
            description:
                'You must not be serving as a guarantor for any active loan.',
          ),
          _buildImplicationItem(
            number: '4',
            title: 'Data Retention',
            description:
                'Your financial records will be retained for regulatory compliance.',
          ),
          _buildImplicationItem(
            number: '5',
            title: 'No Re-registration',
            description:
                'After permanent termination, you cannot create a new account with the same details.',
          ),
        ],
      ),
    );
  }

  Widget _buildImplicationItem({
    required String number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: CoopvestColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: CoopvestColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CoopvestColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendAuthorityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CoopvestColors.info.withAlpha((255 * 0.1).toInt()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CoopvestColors.info.withAlpha((255 * 0.3).toInt()),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud, color: CoopvestColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Backend Validation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CoopvestColors.info,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'All eligibility checks are performed by our secure backend system. The mobile app only submits requests.',
                  style: TextStyle(
                    fontSize: 11,
                    color: CoopvestColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: CoopvestColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
