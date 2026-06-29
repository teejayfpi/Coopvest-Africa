import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../widgets/common/buttons.dart';

/// Contribution type selection before KYC registration
enum ContributionType { directDeposit, salaryDeduction }

/// Contribution Type Selection Screen
/// This screen appears BEFORE KYC registration starts
/// Users must select their preferred contribution method:
/// - Direct Deposit: User makes payments manually
/// - Salary Deduction: Employer deducts from salary (requires employer info)
class ContributionTypeSelectionScreen extends ConsumerStatefulWidget {
  final Map<String, String> registrationData;

  const ContributionTypeSelectionScreen({
    Key? key,
    required this.registrationData,
  }) : super(key: key);

  @override
  ConsumerState<ContributionTypeSelectionScreen> createState() =>
      _ContributionTypeSelectionScreenState();
}

class _ContributionTypeSelectionScreenState
    extends ConsumerState<ContributionTypeSelectionScreen> {
  ContributionType? _selectedType;

  void _onTypeSelected(ContributionType type) {
    setState(() {
      _selectedType = type;
    });
  }

  void _continueToRegistration() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a contribution type to continue'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    // Add contribution type to registration data
    final updatedData = Map<String, String>.from(widget.registrationData);
    updatedData['contribution_type'] =
        _selectedType == ContributionType.directDeposit
            ? 'direct_deposit'
            : 'salary_deduction';

    // Navigate to registration onboarding
    Navigator.of(context).pushNamed(
      '/register-step3',
      arguments: updatedData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.scaffoldBackground,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Contribution Type',
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
              // Header
              Text(
                'How would you like to contribute?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose your preferred contribution method. This helps us set up your account correctly. You can change this later in your settings.',
                style: TextStyle(
                  fontSize: 15,
                  color: context.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Direct Deposit Option
              _buildTypeCard(
                context,
                type: ContributionType.directDeposit,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Direct Deposit',
                subtitle: 'I will make manual payments',
                description:
                    'You make payments yourself each month via bank transfer, USSD, or card payment.',
                requirements: const [
                  'No employer information required',
                  'Set your own contribution amount',
                  'Choose your preferred payment day',
                  'Receive monthly payment reminders',
                ],
                badge: null,
              ),

              const SizedBox(height: 20),

              // Salary Deduction Option
              _buildTypeCard(
                context,
                type: ContributionType.salaryDeduction,
                icon: Icons.business_center_outlined,
                title: 'Salary Deduction',
                subtitle: 'Deduct from my salary',
                description:
                    'Your employer deducts your contribution directly from your salary each month and remits it to Coopvest.',
                requirements: const [
                  'Employer information required',
                  'Employer must be enrolled with Coopvest',
                  'Automatic monthly deductions',
                  'Consistent and reliable contributions',
                ],
                badge: 'Requires Employer Info',
              ),

              const SizedBox(height: 32),

              // Info notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CoopvestColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CoopvestColors.info.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: CoopvestColors.info,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important',
                            style: TextStyle(
                              color: CoopvestColors.info,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'If you choose Salary Deduction, you will need to provide your employer\'s details during registration. If your employer is not yet enrolled with Coopvest, you can still register and we will help facilitate enrollment.',
                            style: TextStyle(
                              color: CoopvestColors.info,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Continue Button
              PrimaryButton(
                label: _selectedType == null ? 'Select a Contribution Type' : 'Continue',
                onPressed: _continueToRegistration,
                width: double.infinity,
                isEnabled: _selectedType != null,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard(
    BuildContext context, {
    required ContributionType type,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required List<String> requirements,
    String? badge,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => _onTypeSelected(type),
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
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CoopvestColors.primary.withOpacity(0.15)
                        : context.dividerColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? CoopvestColors.primary
                        : context.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
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
                                fontSize: 17,
                              ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: CoopvestColors.warning.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  color: CoopvestColors.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? CoopvestColors.primary
                          : context.dividerColor,
                      width: 2,
                    ),
                    color: isSelected
                        ? CoopvestColors.primary
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 15)
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              description,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),

            // Requirements
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? CoopvestColors.primary.withOpacity(0.05)
                    : context.secondaryCardBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What\'s included:',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...requirements.map((req) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: isSelected
                                  ? CoopvestColors.primary
                                  : context.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                req,
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
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}