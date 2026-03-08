import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_config.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/referral_models.dart';
import '../../../presentation/providers/referral_provider.dart';
import '../../../presentation/providers/wallet_provider.dart';
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
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _monthlySavingsController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    // Load wallet data for savings-based loan limits
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).loadWallet();
    });
  }

  // Loan Types Configuration
  // Now uses savings-based multipliers instead of fixed amounts
  // Premium Loan: 4x savings, Maxi Loan: 5x savings, Others: 3x savings
  final Map<String, Map<String, dynamic>> _loanTypes = {
    'Quick Loan': {
      'duration': 4,
      'interest': 7.5,
      'multiplier': 3.0, // 3x savings
      'description': 'Short-term emergency cash for members in urgent need',
    },
    'Flexi Loan': {
      'duration': 6,
      'interest': 7.0,
      'multiplier': 3.0, // 3x savings
      'description': 'Flexible repayment plan for personal or business needs',
    },
    'Stable Loan (12 months)': {
      'duration': 12,
      'interest': 5.0,
      'multiplier': 3.0, // 3x savings
      'description': 'Long-term stability with the lowest interest rate',
    },
    'Stable Loan (18 months)': {
      'duration': 18,
      'interest': 7.0,
      'multiplier': 3.0, // 3x savings
      'description': 'Extended repayment for larger projects or investments',
    },
    'Premium Loan': {
      'duration': 24,
      'interest': 14.0,
      'multiplier': 4.0, // 4x savings - Special for premium members
      'description': 'Premium access for established members with higher limits',
    },
    'Maxi Loan': {
      'duration': 36,
      'interest': 19.0,
      'multiplier': 5.0, // 5x savings - Maximum for major investments
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
      final multiplier = (loanInfo['multiplier'] as num).toDouble();
      final requestedAmount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
      final monthlySavings = double.tryParse(_monthlySavingsController.text.replaceAll(',', '')) ?? 0.0;
      
      // Get member's savings for limit calculation
      final walletState = ref.read(walletProvider);
      final memberSavings = walletState.wallet?.totalSavings ?? walletState.wallet?.balance ?? 0.0;
      
      // Calculate limits based on savings
      final minAmount = 1000.0;
      final maxAmount = memberSavings * multiplier;

      // Validate amount range based on savings
      if (requestedAmount < minAmount) {
        setState(() {
          _loanStatus = 'Rejected';
          _rejectionReason = 'Minimum amount is \u20a6${minAmount.toStringAsFixed(0)}';
          _isSubmitting = false;
        });
        return;
      }

      if (requestedAmount > maxAmount) {
        setState(() {
          _loanStatus = 'Rejected';
          _rejectionReason = 'Maximum amount for ${_selectedLoanType} is \u20a6${maxAmount.toStringAsFixed(0)} (${multiplier}x your savings)';
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
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: CoopvestColors.success),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your ${_selectedLoanType} application has been APPROVED!', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'To complete the process, please share the QR code (now visible at the bottom of the screen) with your 3 guarantors.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          PrimaryButton(
            label: 'View QR Code',
            onPressed: () {
              Navigator.of(context).pop();
              // The QR code is already shown because _showQrCode is true
            },
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
    final multiplier = (loanInfo['multiplier'] as num).toDouble();
    
    // Get member's savings from wallet provider
    final walletState = ref.watch(walletProvider);
    final memberSavings = walletState.wallet?.totalSavings ?? walletState.wallet?.balance ?? 0.0;
    
    // Calculate min and max based on savings multiplier
    final minAmount = 1000.0; // Minimum loan of ₦1,000
    final maxAmount = memberSavings * multiplier;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? CoopvestColors.darkBackground : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? CoopvestColors.darkSurface : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : CoopvestColors.darkGray),
          onPressed: _goBack,
        ),
        title: Text(
          'Apply for Loan',
          style: CoopvestTypography.headlineLarge.copyWith(
            color: isDarkMode ? Colors.white : CoopvestColors.darkGray,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                          value: _selectedLoanType,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down),
                          isExpanded: true, // Allow dropdown to take full width
                          items: _loanTypes.entries.map((entry) {
                            final key = entry.key;
                            final value = entry.value;
                            return DropdownMenuItem(
                              value: key,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    key,
                                    style: CoopvestTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${value['duration']}m @ ${value['interest']}%',
                                    style: CoopvestTypography.bodySmall.copyWith(
                                      color: CoopvestColors.mediumGray,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
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
                                color: isDarkMode ? CoopvestColors.darkSurface : CoopvestColors.veryLightGray,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Min: \u20a6${minAmount.toStringAsFixed(0)}',
                                style: CoopvestTypography.bodySmall.copyWith(
                                  color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDarkMode ? CoopvestColors.darkSurface : CoopvestColors.veryLightGray,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Max: \u20a6${maxAmount.toStringAsFixed(0)}',
                                style: CoopvestTypography.bodySmall.copyWith(
                                  color: isDarkMode ? CoopvestColors.darkText : CoopvestColors.darkGray,
                                ),
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
                      _buildInfoRow('• You need 3 guarantors to approve this loan'),
                      _buildInfoRow('• Guarantors must be existing members'),
                      _buildInfoRow('• Monthly savings must be at least 10% of loan amount'),
                      _buildInfoRow('• Defaulting loans will be inherited by guarantors'),
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
      ),
    );
  }

  Widget _buildInfoRow(String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: CoopvestTypography.bodySmall.copyWith(
          color: isDarkMode ? Colors.white : CoopvestColors.darkGray,
          fontWeight: FontWeight.w500,
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Loan Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          _buildSummaryRow('Requested Amount', '\u20a6${amount.toStringAsFixed(2)}'),
          _buildSummaryRow('Interest Rate', '${interestRate}%'),
          _buildSummaryRow('Tenure', '${tenure} Months'),
          _buildSummaryRow('Monthly Repayment', '\u20a6${monthlyRepayment.toStringAsFixed(2)}', isBold: true),
          _buildSummaryRow('Total Repayment', '\u20a6${totalRepayment.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.textSecondary)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildReferralBonusSection(BuildContext context, WidgetRef ref, Map<String, dynamic> loanInfo) {
    final referralState = ref.watch(referralProvider);
    final referrals = referralState.referrals;
    final activeReferralsCount = referrals.where((r) => r.confirmed && !r.isFlagged).length;
    
    // Tiered interest reduction based on active referrals
    double reduction = 0;
    if (activeReferralsCount >= 10) reduction = 2.0;
    else if (activeReferralsCount >= 5) reduction = 1.0;
    else if (activeReferralsCount >= 2) reduction = 0.5;

    final originalInterest = (loanInfo['interest'] as num).toDouble();
    final finalInterest = max(0.0, originalInterest - reduction);

    return AppCard(
      backgroundColor: CoopvestColors.primary.withAlpha((255 * 0.1).toInt()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: CoopvestColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Referral Bonus', style: TextStyle(fontWeight: FontWeight.bold, color: CoopvestColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Active Referrals: $activeReferralsCount', style: const TextStyle(fontSize: 12)),
          if (reduction > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Interest reduced by ${reduction}%! (Original: ${originalInterest}%, New: ${finalInterest}%)',
                style: const TextStyle(color: CoopvestColors.success, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Refer more members to reduce your loan interest rate!',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      children: [
        AppCard(
          child: Column(
            children: [
              const Text('Loan Application QR Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text('Status: $_loanStatus', style: TextStyle(
                color: _loanStatus == 'Approved' ? CoopvestColors.success : Colors.orange,
                fontWeight: FontWeight.bold,
              )),
              const SizedBox(height: 24),
              QrImageView(
                data: _formattedLoanId,
                version: QrVersions.auto,
                size: 200.0,
                foregroundColor: isDarkMode ? Colors.white : Colors.black,
              ),
              const SizedBox(height: 16),
              Text(_formattedLoanId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                'Share this code with your 3 guarantors. They must scan it to approve your application.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: CoopvestColors.mediumGray),
              ),
            ],
          ),
        ),
      ],
    );
  }
}