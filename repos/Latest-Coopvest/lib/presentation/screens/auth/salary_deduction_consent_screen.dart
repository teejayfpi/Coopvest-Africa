import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/services/api_service.dart';
import '../../widgets/common/buttons.dart';

/// Salary Deduction & Loan Recovery Consent Screen
class SalaryDeductionConsentScreen extends ConsumerStatefulWidget {
  final Map<String, String> registrationData;

  const SalaryDeductionConsentScreen({
    Key? key,
    required this.registrationData,
  }) : super(key: key);

  @override
  ConsumerState<SalaryDeductionConsentScreen> createState() => _SalaryDeductionConsentScreenState();
}

class _SalaryDeductionConsentScreenState extends ConsumerState<SalaryDeductionConsentScreen> {
  bool _agreeToConsent = false;
  bool _isSubmitting = false;
  final ApiService _apiService = ApiService();

  Future<void> _submitConsent() async {
    if (!_agreeToConsent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please read and accept the consent'), backgroundColor: CoopvestColors.error));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final response = await _apiService.post('/auth/salary-consent', data: {
        'memberId': widget.registrationData['memberId'] ?? '',
        'consent': _agreeToConsent,
        'timestamp': DateTime.now().toIso8601String(),
      });
      if (response['success'] == true && mounted) {
        Navigator.of(context).pushReplacementNamed('/account-activation');
      } else {
        throw Exception(response['message'] ?? 'Failed to submit consent');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: CoopvestColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        title: Text('Consent & Authorization', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CoopvestColors.warning.withOpacity(0.1),
                  border: Border.all(color: CoopvestColors.warning),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: CoopvestColors.warning, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This is a mandatory consent required to access loans',
                        style: TextStyle(color: CoopvestColors.warning, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Salary Deduction & Loan Recovery Authorization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConsentSection(context, 'Authorization for Salary Deduction', 'I authorize Coopvest Africa to deduct agreed loan repayments directly from my salary.'),
                    const SizedBox(height: 16),
                    _buildConsentSection(context, 'Scope of Authorization', 'This applies to loans, contributions, and recovery actions.'),
                    const SizedBox(height: 16),
                    _buildConsentSection(context, 'Information Sharing', 'I consent to sharing payroll information for deduction purposes.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => setState(() => _agreeToConsent = !_agreeToConsent),
                child: Row(
                  children: [
                    Checkbox(value: _agreeToConsent, onChanged: (v) => setState(() => _agreeToConsent = v ?? false), activeColor: CoopvestColors.primary),
                    Expanded(child: Text('I agree to the Salary Deduction Authorization', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(label: 'Accept & Continue', onPressed: _submitConsent, isLoading: _isSubmitting, width: double.infinity),
              const SizedBox(height: 16),
              SecondaryButton(
                label: 'Decline',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: context.cardBackground,
                      title: Text('Decline Consent?', style: TextStyle(color: context.textPrimary)),
                      content: Text('You cannot access loans without accepting this consent.', style: TextStyle(color: context.textSecondary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        TextButton(onPressed: () { Navigator.pop(context); Navigator.of(context).pushNamed('/home'); }, child: const Text('Proceed Without Loans')),
                      ],
                    ),
                  );
                },
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(content, style: TextStyle(color: context.textSecondary, fontSize: 12, height: 1.6)),
      ],
    );
  }
}
