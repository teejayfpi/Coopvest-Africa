import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

/// KYC Status Card - shows user's KYC approval status
class KycStatusCard extends StatelessWidget {
  final String status; // pending, approved, rejected
  final VoidCallback? onTap;

  const KycStatusCard({
    super.key,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KYC Verification',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 14,
                      ),
                    ),
                    if (status == 'pending') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Usually takes 24-48 hours',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (status) {
      case 'approved':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.verified_user, color: Colors.green),
        );
      case 'rejected':
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.cancel, color: Colors.red),
        );
      default:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.pending, color: Colors.orange),
        );
    }
  }

  String _getStatusText() {
    switch (status) {
      case 'approved':
        return 'Verified ✓';
      case 'rejected':
        return 'Verification Failed';
      default:
        return 'Under Review';
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

/// KYC Status Banner - compact status indicator
class KycStatusBanner extends StatelessWidget {
  final String status;

  const KycStatusBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'approved') return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBannerColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBannerColor().withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(_getBannerIcon(), color: _getBannerColor(), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getBannerText(),
              style: TextStyle(
                color: _getBannerColor(),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBannerColor() {
    switch (status) {
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getBannerIcon() {
    switch (status) {
      case 'rejected':
        return Icons.warning_amber;
      default:
        return Icons.info_outline;
    }
  }

  String _getBannerText() {
    switch (status) {
      case 'rejected':
        return 'KYC verification failed. Please update your documents.';
      default:
        return 'KYC verification in progress. You\'ll be notified once approved.';
    }
  }
}

/// Progress Step Indicator for multi-step processes
class ProgressStepIndicator extends StatelessWidget {
  final List<StepData> steps;
  final int currentStep;

  const ProgressStepIndicator({
    super.key,
    required this.steps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = index ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: stepIndex < currentStep
                  ? CoopvestColors.primary
                  : Colors.grey.shade300,
            ),
          );
        }
        // Step circle
        final stepIndex = index ~/ 2;
        final step = steps[stepIndex];
        final isCompleted = stepIndex < currentStep;
        final isCurrent = stepIndex == currentStep;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? CoopvestColors.primary
                    : isCurrent
                        ? CoopvestColors.primary.withOpacity(0.2)
                        : Colors.grey.shade300,
                border: isCurrent
                    ? Border.all(color: CoopvestColors.primary, width: 2)
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          color: isCurrent ? CoopvestColors.primary : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(
                step.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isCurrent ? CoopvestColors.primary : Colors.grey,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Data class for progress steps
class StepData {
  final String label;
  final IconData? icon;

  const StepData({required this.label, this.icon});
}