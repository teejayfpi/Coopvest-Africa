import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/network/api_client.dart';
import '../../../presentation/widgets/common/buttons.dart';

/// Contribution method options
enum ContributionMethodOption { manual, payroll }

/// Contribution Method Selection Screen
/// Allows users to select how they want to make contributions:
/// - Manual monthly self-contribution
/// - Salary/payroll deduction via employer
class ContributionMethodScreen extends ConsumerStatefulWidget {
  final ContributionMethodOption? currentMethod;
  final bool isOnboarding;

  const ContributionMethodScreen({
    super.key,
    this.currentMethod,
    this.isOnboarding = false,
  });

  @override
  ConsumerState<ContributionMethodScreen> createState() =>
      _ContributionMethodScreenState();
}

class _ContributionMethodScreenState
    extends ConsumerState<ContributionMethodScreen> {
  ContributionMethodOption? _selectedMethod;
  double _contributionAmount = 5000;
  int _contributionDay = 5;
  final _amountController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.currentMethod;
    _amountController.text = _contributionAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveMethod() async {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a contribution method'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Call API to update contribution method
      // The ApiClient's AuthInterceptor handles token automatically
      final apiClient = ref.read(apiClientProvider);
      
      await apiClient.put(
        '/user/contribution-method',
        data: {
          'method': _selectedMethod == ContributionMethodOption.manual ? 'manual' : 'payroll',
          'monthlyAmount': _selectedMethod == ContributionMethodOption.manual ? _contributionAmount : null,
          'preferredDay': _selectedMethod == ContributionMethodOption.manual ? _contributionDay : null,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedMethod == ContributionMethodOption.manual
                  ? 'Manual contribution method saved.'
                  : 'Payroll deduction request submitted.',
            ),
            backgroundColor: CoopvestColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: CoopvestColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.scaffoldBackground,
        leading: widget.isOnboarding
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back, color: context.iconPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          'Contribution Method',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How would you like to contribute?',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the method that works best for you. You can change this later in your settings.',
                style: TextStyle(color: context.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 28),

              // Manual option
              _buildMethodCard(
                context,
                method: ContributionMethodOption.manual,
                icon: Icons.calendar_month_outlined,
                title: 'Monthly Self Contribution',
                subtitle:
                    'You make payments manually each month via bank transfer, card, or wallet.',
                features: const [
                  'Set your own contribution amount',
                  'Choose your preferred payment day',
                  'Pay via bank transfer, card, or wallet',
                  'Receive monthly reminders',
                ],
              ),

              const SizedBox(height: 16),

              // Payroll option
              _buildMethodCard(
                context,
                method: ContributionMethodOption.payroll,
                icon: Icons.business_center_outlined,
                title: 'Salary Deduction (Payroll)',
                subtitle:
                    'Your employer deducts your contribution directly from your salary each month.',
                features: const [
                  'Automatic — no action needed monthly',
                  'Deducted before salary is paid',
                  'Your employer handles remittance',
                  'Available only for enrolled organizations',
                ],
                badge: 'Employer Required',
              ),

              const SizedBox(height: 28),

              // Extra config for manual
              if (_selectedMethod == ContributionMethodOption.manual)
                _buildManualConfig(context),

              // Payroll info
              if (_selectedMethod == ContributionMethodOption.payroll)
                _buildPayrollInfo(context),

              const SizedBox(height: 32),

              _isSaving
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: CoopvestColors.primary))
                  : PrimaryButton(
                      label: widget.isOnboarding ? 'Confirm & Continue' : 'Save Method',
                      onPressed: _saveMethod,
                      width: double.infinity,
                    ),

              if (!widget.isOnboarding) ...[
                const SizedBox(height: 16),
                SecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  width: double.infinity,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodCard(
    BuildContext context, {
    required ContributionMethodOption method,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> features,
    String? badge,
  }) {
    final isSelected = _selectedMethod == method;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? CoopvestColors.primary.withOpacity(0.07)
              : context.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? CoopvestColors.primary : context.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CoopvestColors.primary.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CoopvestColors.primary.withOpacity(0.15)
                        : context.dividerColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? CoopvestColors.primary
                        : context.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: CoopvestColors.info.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: CoopvestColors.info,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                            color: context.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? CoopvestColors.primary
                          : context.dividerColor,
                      width: 2,
                    ),
                    color: isSelected ? CoopvestColors.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 13)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 15,
                      color: isSelected
                          ? CoopvestColors.primary
                          : context.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? context.textPrimary
                              : context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualConfig(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Up Your Contribution',
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Text('Monthly Amount (₦)',
              style: TextStyle(color: context.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              prefixText: '₦ ',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) {
              final val = double.tryParse(v.replaceAll(',', ''));
              if (val != null) setState(() => _contributionAmount = val);
            },
          ),
          const SizedBox(height: 16),
          Text('Preferred Payment Day (1–28)',
              style: TextStyle(color: context.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [1, 5, 10, 15, 20, 25, 28].map((day) {
              final isSelected = _contributionDay == day;
              return GestureDetector(
                onTap: () => setState(() => _contributionDay = day),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CoopvestColors.primary
                        : context.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isSelected
                            ? CoopvestColors.primary
                            : context.dividerColor),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isSelected ? Colors.white : context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CoopvestColors.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: CoopvestColors.info, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You will receive a reminder on the ${_contributionDay}th of each month to make your contribution of ₦${_contributionAmount.toStringAsFixed(0)}.',
                    style:
                        const TextStyle(color: CoopvestColors.info, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CoopvestColors.info.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CoopvestColors.info.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: CoopvestColors.info, size: 18),
              SizedBox(width: 8),
              Text(
                'How Payroll Deduction Works',
                style: TextStyle(
                  color: CoopvestColors.info,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoStep('1', 'Your organization must be enrolled with Coopvest for payroll deductions.'),
          const SizedBox(height: 8),
          _buildInfoStep('2', 'Your employer deducts the agreed amount from your salary each month.'),
          const SizedBox(height: 8),
          _buildInfoStep('3', 'Coopvest receives the remittance and credits your savings account.'),
          const SizedBox(height: 8),
          _buildInfoStep('4', 'You get notified once your contribution is received.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CoopvestColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'If your organization is not yet enrolled, contact support to initiate the process. Salary deduction will only be activated once your organization is confirmed.',
              style: TextStyle(color: CoopvestColors.warning, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: CoopvestColors.info,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(step,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: CoopvestColors.info, fontSize: 12)),
        ),
      ],
    );
  }
}
