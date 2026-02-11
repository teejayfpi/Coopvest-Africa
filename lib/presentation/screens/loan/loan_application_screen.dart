import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../data/models/referral_models.dart';
import '../../../presentation/providers/referral_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/inputs.dart';

/// Loan Application Screen with 6 Loan Types and QR-based 3-Guarantor System
/// Now includes Referral Bonus Section for tiered interest reduction
class LoanApplicationScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final String userPhone;

  const LoanApplicationScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userPhone,
  });

  @override
  ConsumerState<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends ConsumerState<LoanApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _monthlySavingsController = TextEditingController();

  // Loan Types Configuration
  final Map<String, Map<String, dynamic>> _loanTypes = {
    'Quick Loan': {
      'duration': 4,
      'interest': 7.5,
      'minAmount': 5000.0,
      'maxAmount': 50000.0,
      'description': 'Short-term emergency cash for members in urgent need',
    },
    'Flexi Loan': {
      'duration': 6,
      'interest': 7.0,
      'minAmount': 10000.0,
      'maxAmount': 100000.0,
      'description': 'Flexible repayment plan for personal or business needs',
    },
    'Stable Loan (12 months)': {
      'duration': 12,
      'interest': 5.0,
      'minAmount': 20000.0,
      'maxAmount': 200000.0,
      'description': 'Long-term stability with the lowest interest rate',
    },
    'Stable Loan (18 months)': {
      'duration': 18,
      'interest': 7.0,
      'minAmount': 30000.0,
      'maxAmount': 300000.0,
      'description': 'Extended repayment for larger projects or investments',
    },
    'Premium Loan': {
      'duration': 24,
      'interest': 14.0,
      'minAmount': 50000.0,
      'maxAmount': 500000.0,
      'description': 'Premium access for established members with higher limits',
    },
    'Maxi Loan': {
      'duration': 36,
      'interest': 19.0,
      'minAmount': 100000.0,
      'maxAmount': 1000000.0,
      'description': 'Maximum loan for major investments and business expansion',
    },
  };

  String _selectedLoanType = 'Quick Loan';
  String _loanStatus = '';
  String _loanId = '';
  String? _rejectionReason;
  bool _showQrCode = false;
  bool _isSubmitting = false;

  // Calculate monthly repayment
  double _calculateMonthlyRepayment(double amount, double interestRate, int tenure) {
    final principal = amount;
    final rate = interestRate / 100 / 12;
    final months = tenure;
    
    // EMI = P * r * (1 + r)^n / ((1 + r)^n - 1)
    final emi = principal * rate * pow(1 + rate, months) / (pow(1 + rate, months) - 1);
    return emi;
  }

  // Calculate total repayment
  double _calculateTotalRepayment(double amount, double interestRate) {
    return amount + (amount * interestRate / 100);
  }

  String get _formattedLoanId => 'COOP-${_loanId}';

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _loanStatus = 'Processing';
      _rejectionReason = null;
    });

    try {
      final loanInfo = _loanTypes[_selectedLoanType]!;
      final requestedAmount = double.parse(_amountController.text.replaceAll(',', ''));
      final monthlySavings = double.tryParse(_monthlySavingsController.text) ?? 0.0;

      // Validate amount range
      if (requestedAmount < (loanInfo['minAmount'] as num).toDouble()) {
        setState(() {
          _loanStatus = 'Rejected';
          _rejectionReason = 'Minimum amount for ${_selectedLoanType} is \u20a6${loanInfo['minAmount']}';
          _isSubmitting = false;
        });
        return;
      }

      if (requestedAmount > (loanInfo['maxAmount'] as num).toDouble()) {
        setState(() {
          _loanStatus = 'Rejected';
          _rejectionReason = 'Maximum amount for ${_selectedLoanType} is \u20a6${loanInfo['maxAmount']}';
          _isSubmitting = false;
        });
        return;
      }

      // Validate monthly savings (must be at least 10% of loan amount)
      if (monthlySavings < requestedAmount * 0.1) {
        setState(() {
          _loanStatus = 'Rejected';
          _rejectionReason = 'Monthly savings commitment must be at least 10% of loan amount (\u20a6${(requestedAmount * 0.1).toStringAsFixed(2)})';
          _isSubmitting = false;
        });
        return;
      }

      // Generate unique loan ID
      final loanId = '${widget.userId}-LOAN-${DateTime.now().millisecondsSinceEpoch}';
      
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // Simple approval logic (in production, this would be based on credit score, etc.)
      if (monthlySavings >= requestedAmount * 0.15) {
        // 15% or higher = Approved
        setState(() {
          _loanId = loanId;
          _loanStatus = 'Approved';
          _rejectionReason = null;
          _showQrCode = true;
          _isSubmitting = false;
        });

        // Show success dialog
        _showSuccessDialog();
      } else if (monthlySavings >= requestedAmount * 0.1) {
        // 10-15% = Pending Review
        setState(() {
          _loanId = loanId;
          _loanStatus = 'Pending Review';
          _rejectionReason = null;
          _showQrCode = true;
          _isSubmitting = false;
        });

        _showPendingDialog();
      } else {
        setState(() {
          _loanStatus = 'Rejected';
          _rejectionReason = 'Monthly savings commitment is too low. Minimum 10% required.';
          _isSubmitting = false;
        });
      }

    } catch (e) {
      setState(() {
        _loanStatus = 'Error';
        _rejectionReason = 'Failed to process application: $e';
        _isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: CoopvestColors.success),
            SizedBox(width: 8),
            Text('Congratulations!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your ${_selectedLoanType} application has been APPROVED!'),
            const SizedBox(height: 16),
            const Text(
              'Please share the QR code with your 3 guarantors. They need to scan it to confirm their guarantee.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPendingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.hourglass_top, color: Colors.orange),
            SizedBox(width: 8),
            Text('Under Review'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your ${_selectedLoanType} application is now under review.'),
            const SizedBox(height: 16),
            const Text(
              'Please share the QR code with your 3 guarantors. Once all 3 guarantors confirm, your loan will be processed.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    _monthlySavingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loanInfo = _loanTypes[_selectedLoanType]!;
    final minAmount = (loanInfo['minAmount'] as num).toDouble();
    final maxAmount = (loanInfo['maxAmount'] as num).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CoopvestColors.darkGray),
          onPressed: _goBack,
        ),
        title: Text(
          'Apply for Loan',
          style: CoopvestTypography.headlineLarge.copyWith(
            color: CoopvestColors.darkGray,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Loan Type Selection Card
              AppCard(
                backgroundColor: CoopvestColors.primary.withAlpha((255 * 0.05).toInt()),
                border: Border.all(color: CoopvestColors.primary.withAlpha((255 * 0.2).toInt())),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance, color: CoopvestColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Select Loan Type',
                          style: CoopvestTypography.labelLarge.copyWith(
                            color: CoopvestColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: CoopvestColors.lightGray),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedLoanType,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items: _loanTypes.entries.map((entry) {
                          final key = entry.key;
                          final value = entry.value;
                          return DropdownMenuItem(
                            value: key,
                            child: SizedBox(
                              height: 48, // Fixed height to prevent overflow
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    key,
                                    style: CoopvestTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${value['duration']} months @ ${value['interest']}% interest',
                                    style: CoopvestTypography.bodySmall.copyWith(
                                      color: CoopvestColors.mediumGray,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLoanType = value!;
                            _amountController.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      loanInfo['description'] as String,
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: CoopvestColors.mediumGray,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: CoopvestColors.veryLightGray,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Min: \u20a6${minAmount.toStringAsFixed(0)}',
                              style: CoopvestTypography.bodySmall,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: CoopvestColors.veryLightGray,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Max: \u20a6${maxAmount.toStringAsFixed(0)}',
                              style: CoopvestTypography.bodySmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Loan Amount
              AppTextField(
                label: 'Loan Amount (\u20a6) *',
                hint: 'Enter amount between \u20a6${minAmount.toStringAsFixed(0)} - \u20a6${maxAmount.toStringAsFixed(0)}',
                controller: _amountController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                prefixText: '\u20a6 ',
                onChanged: (value) {
                  setState(() {});
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter loan amount';
                  }
                  final amount = double.tryParse(value.replaceAll(',', ''));
                  if (amount == null) {
                    return 'Please enter a valid number';
                  }
                  if (amount < minAmount) {
                    return 'Minimum amount is \u20a6${minAmount.toStringAsFixed(0)}';
                  }
                  if (amount > maxAmount) {
                    return 'Maximum amount is \u20a6${maxAmount.toStringAsFixed(0)}';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Monthly Savings While on Loan
              AppTextField(
                label: 'Monthly Savings While On Loan (\u20a6) *',
                hint: 'Minimum 10% of loan amount required',
                controller: _monthlySavingsController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                prefixText: '\u20a6 ',
                onChanged: (value) {
                  setState(() {});
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter monthly savings amount';
                  }
                  final savings = double.tryParse(value);
                  if (savings == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              // Show calculated values and referral bonus
              if (_amountController.text.isNotEmpty && _monthlySavingsController.text.isNotEmpty)
                ...[
                  const SizedBox(height: 16),
                  _buildLoanSummary(loanInfo),
                  const SizedBox(height: 16),
                  _buildReferralBonusSection(context, ref, loanInfo),
                ],

              const SizedBox(height: 16),

              // Loan Purpose
              AppTextField(
                label: 'Loan Purpose *',
                hint: 'Briefly describe why you need this loan',
                controller: _purposeController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter loan purpose';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Important Notice Card
              AppCard(
                backgroundColor: CoopvestColors.warning.withAlpha((255 * 0.1).toInt()),
                border: Border.all(color: CoopvestColors.warning.withAlpha((255 * 0.3).toInt())),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: CoopvestColors.warning),
                        const SizedBox(width: 8),
                        Text(
                          'Important Requirements',
                          style: CoopvestTypography.labelLarge.copyWith(
                            color: CoopvestColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('\u2022 You need 3 guarantors to approve this loan'),
                    _buildInfoRow('\u2022 Guarantors must be existing members'),
                    _buildInfoRow('\u2022 Monthly savings must be at least 10% of loan amount'),
                    _buildInfoRow('\u2022 Defaulting loans will be inherited by guarantors'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              _isSubmitting
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: CoopvestColors.primary,
                      ),
                    )
                  : PrimaryButton(
                      label: 'Submit Application',
                      onPressed: _submitApplication,
                      width: double.infinity,
                    ),

              const SizedBox(height: 16),

              // Back Button
              SecondaryButton(
                label: 'Go Back',
                onPressed: _goBack,
                width: double.infinity,
              ),

              // QR Code and Status Section
              if (_showQrCode) ...[
                const SizedBox(height: 32),
                _buildStatusSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: CoopvestTypography.bodySmall.copyWith(
          color: CoopvestColors.darkGray,
        ),
      ),
    );
  }

  Widget _buildLoanSummary(Map<String, dynamic> loanInfo) {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final savings = double.tryParse(_monthlySavingsController.text) ?? 0;
    final interestRate = (loanInfo['interest'] as num).toDouble();
    final tenure = loanInfo['duration'] as int;
    
    final monthlyRepayment = _calculateMonthlyRepayment(amount, interestRate, tenure);
    final totalRepayment = _calculateTotalRepayment(amount, interestRate);

    final isValidSavings = savings >= amount * 0.1;
    final savingsPercentage = amount > 0 ? (savings / amount * 100) : 0;

    return AppCard(
      backgroundColor: isValidSavings 
          ? CoopvestColors.success.withAlpha((255 * 0.05).toInt())
          : CoopvestColors.error.withAlpha((255 * 0.05).toInt()),
      border: Border.all(
        color: isValidSavings 
            ? CoopvestColors.success 
            : CoopvestColors.error,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Summary',
            style: CoopvestTypography.labelLarge.copyWith(
              color: CoopvestColors.darkGray,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Loan Amount:', '\u20a6${amount.toStringAsFixed(2)}'),
          _buildSummaryRow('Interest Rate:', '${interestRate}%'),
          _buildSummaryRow('Duration:', '$tenure months'),
          _buildSummaryRow('Monthly Repayment:', '\u20a6${monthlyRepayment.toStringAsFixed(2)}'),
          _buildSummaryRow('Total Repayment:', '\u20a6${totalRepayment.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isValidSavings 
                  ? CoopvestColors.success.withAlpha((255 * 0.1).toInt())
                  : CoopvestColors.error.withAlpha((255 * 0.1).toInt()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isValidSavings ? Icons.check_circle : Icons.warning,
                  color: isValidSavings ? CoopvestColors.success : CoopvestColors.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isValidSavings 
                      ? 'Savings: ${savingsPercentage.toStringAsFixed(1)}% of loan \u2713'
                      : 'Savings: ${savingsPercentage.toStringAsFixed(1)}% of loan (Min 10% required)',
                  style: CoopvestTypography.bodySmall.copyWith(
                    color: isValidSavings ? CoopvestColors.success : CoopvestColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralBonusSection(BuildContext context, WidgetRef ref, Map<String, dynamic> loanInfo) {
    final referralState = ref.watch(referralProvider);
    final summary = referralState.summary;
    final currentBonus = summary?.currentTierBonus ?? 0;
    final isBonusAvailable = summary?.isBonusAvailable ?? false;
    final confirmedCount = summary?.confirmedReferrals ?? 0;
    
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final tenure = loanInfo['duration'] as int;
    final baseRate = (loanInfo['interest'] as num).toDouble();
    
    // Calculate savings from referral bonus
    final monthlyRateBefore = baseRate / 100 / 12;
    final emiBefore = amount * monthlyRateBefore * pow(1 + monthlyRateBefore, tenure) / (pow(1 + monthlyRateBefore, tenure) - 1);
    
    final effectiveRate = isBonusAvailable && currentBonus > 0 
        ? (baseRate - currentBonus).clamp(LoanInterestCalculation.minimumInterestFloors[_selectedLoanType] ?? 5.0, baseRate)
        : baseRate;
    final monthlyRateAfter = effectiveRate / 100 / 12;
    final emiAfter = amount * monthlyRateAfter * pow(1 + monthlyRateAfter, tenure) / (pow(1 + monthlyRateAfter, tenure) - 1);
    
    final monthlySavings = emiBefore - emiAfter;
    final totalSavings = monthlySavings * tenure;

    if (currentBonus <= 0) {
      // Show tier progress when no bonus yet
      return AppCard(
        backgroundColor: CoopvestColors.info.withAlpha((255 * 0.05).toInt()),
        border: Border.all(color: CoopvestColors.info.withAlpha((255 * 0.2).toInt())),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stars, color: CoopvestColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Referral Bonus',
                    style: CoopvestTypography.labelLarge.copyWith(
                      color: CoopvestColors.info,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Earn interest reduction by referring friends!',
              style: CoopvestTypography.bodyMedium.copyWith(
                color: CoopvestColors.darkGray,
              ),
            ),
            const SizedBox(height: 12),
            _buildTierProgress(context, confirmedCount),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const _ReferralInfoScreen(),
                  ),
                );
              },
              child: const Text('Learn how referral bonuses work'),
            ),
          ],
        ),
      );
    }

    // Show bonus when user has earned it
    return AppCard(
      backgroundColor: isBonusAvailable 
          ? CoopvestColors.success.withAlpha((255 * 0.05).toInt())
          : Colors.orange.withAlpha((255 * 0.05).toInt()),
      border: Border.all(
        color: isBonusAvailable 
            ? CoopvestColors.success 
            : Colors.orange,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBonusAvailable ? Icons.check_circle : Icons.lock_clock,
                color: isBonusAvailable ? CoopvestColors.success : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBonusAvailable ? 'Referral Bonus Applied!' : 'Referral Bonus Locked',
                  style: CoopvestTypography.labelLarge.copyWith(
                    color: isBonusAvailable ? CoopvestColors.success : Colors.orange,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CoopvestColors.success,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '-${currentBonus.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (isBonusAvailable) ...[
            _buildBonusSavingsRow('Base Interest Rate:', '${baseRate}%'),
            _buildBonusSavingsRow('Bonus Reduction:', '-${currentBonus.toStringAsFixed(0)}%'),
            _buildBonusSavingsRow('Effective Rate:', '${effectiveRate.toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CoopvestColors.success.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Savings:',
                        style: CoopvestTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '\u20a6${monthlySavings.toStringAsFixed(2)}',
                        style: CoopvestTypography.titleMedium.copyWith(
                          color: CoopvestColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Savings:',
                        style: CoopvestTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '\u20a6${totalSavings.toStringAsFixed(2)}',
                        style: CoopvestTypography.titleMedium.copyWith(
                          color: CoopvestColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your referral bonus is in the 30-day lock-in period. It will be available for your next loan.',
                      style: CoopvestTypography.bodySmall.copyWith(
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          Text(
            '${confirmedCount} confirmed referrals give you ${currentBonus.toStringAsFixed(0)}% off',
            style: CoopvestTypography.bodySmall.copyWith(
              color: CoopvestColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusSavingsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: CoopvestTypography.bodyMedium.copyWith(
              color: CoopvestColors.mediumGray,
            ),
          ),
          Text(
            value,
            style: CoopvestTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: CoopvestColors.darkGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierProgress(BuildContext context, int confirmedCount) {
    final tiers = [
      {'refs': 0, 'bonus': 0, 'label': 'Start'},
      {'refs': 2, 'bonus': 2, 'label': 'Bronze'},
      {'refs': 4, 'bonus': 3, 'label': 'Silver'},
      {'refs': 6, 'bonus': 4, 'label': 'Gold'},
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: tiers.map((tier) {
            final isReached = confirmedCount >= (tier['refs'] as num).toInt();
            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isReached ? CoopvestColors.success : CoopvestColors.veryLightGray,
                      borderRadius: BorderRadius.circular(16),
                      border: isReached ? null : Border.all(color: CoopvestColors.lightGray),
                    ),
                    child: Center(
                      child: Text(
                        '${tier['bonus']}',
                        style: TextStyle(
                          color: isReached ? Colors.white : CoopvestColors.mediumGray,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tier['refs']}+',
                    style: CoopvestTypography.labelSmall.copyWith(
                      color: CoopvestColors.mediumGray,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: tiers.map((tier) {
            final isReached = confirmedCount >= (tier['refs'] as num).toInt();
            return Expanded(
              child: Center(
                child: Text(
                  tier['label'] as String,
                  style: CoopvestTypography.labelSmall.copyWith(
                    color: isReached ? CoopvestColors.success : CoopvestColors.mediumGray,
                    fontWeight: isReached ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: CoopvestTypography.bodyMedium.copyWith(
              color: CoopvestColors.mediumGray,
            ),
          ),
          Text(
            value,
            style: CoopvestTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: CoopvestColors.darkGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    final isApproved = _loanStatus == 'Approved';
    final isPending = _loanStatus == 'Pending Review';
    final isRejected = _loanStatus == 'Rejected' || _loanStatus == 'Error';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Card
        AppCard(
          backgroundColor: isApproved 
              ? CoopvestColors.success.withAlpha((255 * 0.1).toInt())
              : isPending 
                  ? Colors.yellow[50]
                  : CoopvestColors.error.withAlpha((255 * 0.1).toInt()),
          border: Border.all(
            color: isApproved 
                ? CoopvestColors.success
                : isPending 
                    ? Colors.yellow
                    : CoopvestColors.error,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isApproved 
                        ? Icons.check_circle
                        : isPending 
                            ? Icons.hourglass_top
                            : Icons.cancel,
                    color: isApproved 
                        ? CoopvestColors.success
                        : isPending 
                            ? Colors.orange
                            : CoopvestColors.error,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Application Status: $_loanStatus',
                          style: CoopvestTypography.titleMedium.copyWith(
                            color: isApproved 
                                ? CoopvestColors.success
                                : isPending 
                                    ? Colors.orange
                                    : CoopvestColors.error,
                          ),
                        ),
                        if (isPending)
                          Text(
                            'Waiting for guarantor confirmation',
                            style: CoopvestTypography.bodySmall.copyWith(
                              color: CoopvestColors.mediumGray,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isRejected && _rejectionReason != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Reason: $_rejectionReason',
                  style: CoopvestTypography.bodySmall.copyWith(
                    color: CoopvestColors.error,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // QR Code Section
        if (_showQrCode)
          Center(
            child: Column(
              children: [
                Text(
                  'Share this QR code with your 3 guarantors:',
                  style: CoopvestTypography.titleMedium.copyWith(
                    color: CoopvestColors.darkGray,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: CoopvestColors.primary.withAlpha((255 * 0.1).toInt()),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _formattedLoanId,
                    version: QrVersions.auto,
                    size: 180.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Loan ID: $_formattedLoanId',
                  style: CoopvestTypography.bodyMedium.copyWith(
                    color: CoopvestColors.mediumGray,
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  backgroundColor: CoopvestColors.info.withAlpha((255 * 0.1).toInt()),
                  border: Border.all(color: CoopvestColors.info.withAlpha((255 * 0.3).toInt())),
                  child: Text(
                    'Guarantors should scan this code to confirm their guarantee. If the borrower defaults, the loan is inherited by the 3 guarantors equally.',
                    style: CoopvestTypography.bodySmall.copyWith(
                      color: CoopvestColors.darkGray,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Referral Info Screen - Explains how the referral bonus system works
class _ReferralInfoScreen extends StatelessWidget {
  const _ReferralInfoScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('How Referral Bonuses Work'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                backgroundColor: CoopvestColors.primary.withAlpha((255 * 0.05).toInt()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.stars, color: CoopvestColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Earn Interest Reduction',
                          style: CoopvestTypography.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Invite friends to join Coopvest Africa and earn tiered interest reductions on your loans!',
                      style: CoopvestTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Tier System',
                style: CoopvestTypography.titleLarge,
              ),
              const SizedBox(height: 12),
              
              _buildTierInfoCard(2, 'Bronze', '2 Referrals', '2% OFF'),
              _buildTierInfoCard(3, 'Silver', '4 Referrals', '3% OFF'),
              _buildTierInfoCard(4, 'Gold', '6 Referrals', '4% OFF (Max)'),
              
              const SizedBox(height: 24),
              
              const Text(
                'Qualification Rules',
                style: CoopvestTypography.titleLarge,
              ),
              const SizedBox(height: 12),
              
              _buildRuleRow('1. Referred member registers with your code'),
              _buildRuleRow('2. Member completes KYC verification'),
              _buildRuleRow('3. Member saves consistently for 3 months'),
              _buildRuleRow('4. Member meets minimum savings amount'),
              _buildRuleRow('5. Member passes fraud check'),
              
              const SizedBox(height: 24),
              
              AppCard(
                backgroundColor: Colors.orange.withAlpha((255 * 0.1).toInt()),
                border: Border.all(color: Colors.orange.withAlpha((255 * 0.3).toInt())),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Referral bonuses have a 30-day lock-in period after confirmation before they can be used.',
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              AppCard(
                backgroundColor: CoopvestColors.success.withAlpha((255 * 0.1).toInt()),
                border: Border.all(color: CoopvestColors.success.withAlpha((255 * 0.3).toInt())),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: CoopvestColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The bonus is automatically applied when you apply for a loan. It cannot be applied to penalties, rollovers, or late fees.',
                        style: TextStyle(color: CoopvestColors.success),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierInfoCard(double bonus, String tier, String requirement, String discount) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _getTierColor(tier).withAlpha((255 * 0.2).toInt()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '-${bonus.toStringAsFixed(0)}%',
                style: CoopvestTypography.headlineSmall.copyWith(
                  color: _getTierColor(tier),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$tier Tier',
                  style: CoopvestTypography.titleMedium.copyWith(
                    color: _getTierColor(tier),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  requirement,
                  style: CoopvestTypography.bodyMedium,
                ),
                Text(
                  discount,
                  style: CoopvestTypography.bodySmall.copyWith(
                    color: CoopvestColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'Gold': return const Color(0xFFFFD700);
      case 'Silver': return const Color(0xFFC0C0C0);
      case 'Bronze': return const Color(0xFFCD7F32);
      default: return CoopvestColors.primary;
    }
  }

  Widget _buildRuleRow(String rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: CoopvestColors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              rule,
              style: CoopvestTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
