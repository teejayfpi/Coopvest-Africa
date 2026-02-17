import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../core/services/logger_service.dart';
import '../../../data/models/termination_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/termination_provider.dart';
import '../../widgets/common/buttons.dart';
import '../auth/login_screen.dart';

/// Termination Application Screen
/// Allows users to submit a termination request with reason and acknowledgments
/// Location: Profile → Account Settings → Membership → Terminate Membership → Continue
class TerminationApplicationScreen extends ConsumerWidget {
  const TerminationApplicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final terminationState = ref.watch(terminationProvider);
    final terminationNotifier = ref.read(terminationProvider.notifier);
    final isSubmitting = terminationState.isSubmitting;
    final user = authState.user;

    return Scaffold(
      backgroundColor: CoopvestColors.veryLightGray,
      appBar: AppBar(
        title: const Text('Termination Application'),
        backgroundColor: CoopvestColors.error,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member Info
            _buildMemberInfo(user),
            const SizedBox(height: 24),

            // Reason Selection
            _buildReasonSection(terminationNotifier),
            const SizedBox(height: 24),

            // Exit Type Selection
            _buildExitTypeSection(),
            const SizedBox(height: 24),

            // Additional Details
            _buildDetailsSection(terminationNotifier),
            const SizedBox(height: 24),

            // Acknowledgments
            _buildAcknowledgmentsSection(terminationNotifier),
            const SizedBox(height: 32),

            // Submit Button
            _buildSubmitButton(context, ref, terminationNotifier, isSubmitting),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberInfo(user) {
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: CoopvestColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: CoopvestColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Member',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  user?.id.substring(0, 8).toUpperCase() ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CoopvestColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CoopvestColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                fontSize: 11,
                color: CoopvestColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  final List<TerminationReason> _reasons = [
    TerminationReason.financialDifficulties,
    TerminationReason.noLongerNeedsServices,
    TerminationReason.relocating,
    TerminationReason.foundAlternative,
    TerminationReason.dissatisfied,
    TerminationReason.personalReasons,
    TerminationReason.healthIssues,
    TerminationReason.employmentChange,
    TerminationReason.other,
  ];

  Widget _buildReasonSection(TerminationNotifier notifier) {
    final formData = notifier.state.formData;
    final selectedReason = formData?.reason ?? TerminationReason.other;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reason for Termination',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Please select the primary reason for leaving Coopvest',
          style: TextStyle(
            fontSize: 12,
            color: CoopvestColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
            children: _reasons.asMap().entries.map((entry) {
              final reason = entry.value;
              final isSelected = selectedReason == reason;
              final isLast = entry.key == _reasons.length - 1;

              return Column(
                children: [
                  RadioListTile<TerminationReason>(
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) {
                      if (value != null) {
                        final currentFormData = notifier.state.formData;
                        if (currentFormData != null) {
                          notifier.updateFormData(
                            currentFormData.copyWith(reason: value),
                          );
                        } else {
                          notifier.updateFormData(
                            TerminationFormData(
                              reason: value,
                              exitType: TerminationExitType.permanent,
                              acknowledgedFinancialObligations: false,
                              acknowledgedServiceTermination: false,
                              acknowledgedGuarantorObligations: false,
                            ),
                          );
                        }
                      }
                    },
                    title: Text(
                      getTerminationReasonText(reason),
                      style: const TextStyle(fontSize: 14),
                    ),
                    activeColor: CoopvestColors.error,
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                  if (!isLast) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildExitTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exit Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose how you want to leave Coopvest',
          style: TextStyle(
            fontSize: 12,
            color: CoopvestColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildExitTypeCard(
                type: TerminationExitType.permanent,
                icon: Icons.delete_forever,
                title: 'Permanent',
                description: 'Account will be closed permanently',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExitTypeCard(
                type: TerminationExitType.temporary,
                icon: Icons.pause_circle,
                title: 'Temporary',
                description: 'Account will be suspended, can be reinstated',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExitTypeCard({
    required TerminationExitType type,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final formData = ref.watch(terminationProvider).formData;
        final isSelected = formData?.exitType == type;

        return GestureDetector(
          onTap: () {
            final currentFormData = ref.read(terminationProvider).formData;
            if (currentFormData != null) {
              ref.read(terminationProvider.notifier).updateFormData(
                    currentFormData.copyWith(exitType: type),
                  );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? CoopvestColors.error.withOpacity(0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? CoopvestColors.error : Colors.transparent,
                width: 2,
              ),
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
                Icon(
                  icon,
                  size: 32,
                  color: isSelected ? CoopvestColors.error : CoopvestColors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? CoopvestColors.error : CoopvestColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: CoopvestColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsSection(TerminationNotifier notifier) {
    final formData = notifier.state.formData;
    final reasonController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Provide any additional explanation for your termination (optional)',
          style: TextStyle(
            fontSize: 12,
            color: CoopvestColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
          child: TextFormField(
            controller: reasonController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Please explain your reason for termination...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: CoopvestColors.mediumGray,
              ),
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
            ),
            onChanged: (value) {
              final currentFormData = notifier.state.formData;
              if (currentFormData != null) {
                notifier.updateFormData(
                  currentFormData.copyWith(reasonDetails: value),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAcknowledgmentsSection(TerminationNotifier notifier) {
    final formData = notifier.state.formData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.checklist, color: CoopvestColors.primary),
            SizedBox(width: 8),
            Text(
              'Required Acknowledgments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'You must acknowledge all of the following to submit',
          style: TextStyle(
            fontSize: 12,
            color: CoopvestColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
            children: [
              _buildAcknowledgmentCheckbox(
                title: 'Financial Obligations',
                description:
                    'I confirm that I have no outstanding loans, pending repayments, active investments, or locked savings with Coopvest.',
                isChecked: formData?.acknowledgedFinancialObligations ?? false,
                onChanged: (value) {
                  _updateAcknowledgment(
                    notifier,
                    'financial',
                    value ?? false,
                  );
                },
              ),
              const Divider(height: 1),
              _buildAcknowledgmentCheckbox(
                title: 'Service Termination',
                description:
                    'I understand that terminating my membership will immediately stop all Coopvest services, benefits, and platform access.',
                isChecked: formData?.acknowledgedServiceTermination ?? false,
                onChanged: (value) {
                  _updateAcknowledgment(
                    notifier,
                    'service',
                    value ?? false,
                  );
                },
              ),
              const Divider(height: 1),
              _buildAcknowledgmentCheckbox(
                title: 'Guarantor Obligations',
                description:
                    'I confirm that I am not currently serving as a guarantor for any active loan in the Coopvest system.',
                isChecked: formData?.acknowledgedGuarantorObligations ?? false,
                onChanged: (value) {
                  _updateAcknowledgment(
                    notifier,
                    'guarantor',
                    value ?? false,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcknowledgmentCheckbox({
    required String title,
    required String description,
    required bool isChecked,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      value: isChecked,
      onChanged: onChanged,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        description,
        style: const TextStyle(
          fontSize: 12,
          color: CoopvestColors.textSecondary,
        ),
      ),
      activeColor: CoopvestColors.error,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  void _updateAcknowledgment(
    TerminationNotifier notifier,
    String type,
    bool value,
  ) {
    final currentFormData = notifier.state.formData;
    if (currentFormData != null) {
      switch (type) {
        case 'financial':
          notifier.updateFormData(
            currentFormData.copyWith(acknowledgedFinancialObligations: value),
          );
          break;
        case 'service':
          notifier.updateFormData(
            currentFormData.copyWith(acknowledgedServiceTermination: value),
          );
          break;
        case 'guarantor':
          notifier.updateFormData(
            currentFormData.copyWith(acknowledgedGuarantorObligations: value),
          );
          break;
      }
    }
  }

  Widget _buildSubmitButton(
    BuildContext context,
    WidgetRef ref,
    TerminationNotifier notifier,
    bool isSubmitting,
  ) {
    final formData = notifier.state.formData;
    final isValid = formData?.isValid ?? false;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSubmitting || !isValid
            ? null
            : () => _submitTermination(context, ref),
        style: ElevatedButton.styleFrom(
          backgroundColor: CoopvestColors.error,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 2,
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                'Submit Termination Request',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _submitTermination(BuildContext context, WidgetRef ref) async {
    final formData = ref.read(terminationProvider).formData;

    if (formData == null || !formData.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required acknowledgments'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Termination Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to submit this termination request?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CoopvestColors.warning.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning, color: CoopvestColors.warning),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This action requires admin approval and cannot be undone instantly.',
                      style: TextStyle(
                        fontSize: 12,
                        color: CoopvestColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CoopvestColors.error,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Submit the request
    final success = await ref
        .read(terminationProvider.notifier)
        .submitTerminationRequest(formData: formData);

    if (success && context.mounted) {
      _showSuccessDialog(context, ref);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(terminationProvider).error ??
              'Failed to submit termination request'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    }
  }

  void _showSuccessDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Request Submitted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.check_circle,
              color: CoopvestColors.success,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Your termination request has been submitted successfully.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'It will be reviewed by an admin. You will be notified once a decision is made.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: CoopvestColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close application screen
              Navigator.pop(context); // Close info screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
