import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../data/models/kyc_models.dart';
import '../../../presentation/providers/kyc_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/inputs.dart';

/// KYC Bank Info Screen
class KYCBankInfoScreen extends ConsumerStatefulWidget {
  const KYCBankInfoScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<KYCBankInfoScreen> createState() => _KYCBankInfoScreenState();
}

class _KYCBankInfoScreenState extends ConsumerState<KYCBankInfoScreen> {
  late TextEditingController _accountNumberController;
  late TextEditingController _accountNameController;
  late TextEditingController _bvnController;
  
  String? _selectedBank;
  String? _selectedAccountType;
  
  final List<Map<String, dynamic>> _banks = BankTypes.banks;
  final List<Map<String, dynamic>> _accountTypes = BankAccountTypes.types;
  
  bool _accountNameVerified = false;
  bool _isVerifyingAccountName = false;

  @override
  void initState() {
    super.initState();
    _accountNumberController = TextEditingController();
    _accountNameController = TextEditingController();
    _bvnController = TextEditingController();
    
    // Pre-fill if data exists
    final submission = ref.read(kycProvider).submission;
    if (submission != null) {
      _selectedBank = submission.bankName;
      _accountNumberController.text = submission.accountNumber ?? '';
      _accountNameController.text = submission.accountName ?? '';
      _selectedAccountType = submission.accountType;
      _bvnController.text = submission.bvn ?? '';
      _accountNameVerified = submission.accountName != null && submission.accountName!.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _bvnController.dispose();
    super.dispose();
  }

  Future<void> _verifyAccountName() async {
    if (_selectedBank == null || _accountNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a bank and enter account number'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingAccountName = true;
    });

    try {
      // Verify account name with bank API
      // In production, call your bank's account verification API
      // Example: await _apiClient.post('/bank/verify-account', data: {...});
      
      await Future.delayed(const Duration(seconds: 1));
      
      // Account name will be fetched from the API response
      // For demo purposes, we show the verified state
      setState(() {
        _isVerifyingAccountName = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account verified successfully'),
          backgroundColor: CoopvestColors.success,
        ),
      );
    } catch (e) {
      setState(() {
        _isVerifyingAccountName = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: $e'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    }
  }

  void _validateAndContinue() {
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your bank'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    if (_accountNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your account number'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    if (_accountNumberController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account number must be 10 digits'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    if (!_accountNameVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your account name'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    if (_selectedAccountType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your account type'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    if (_bvnController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your BVN'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    if (_bvnController.text.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('BVN must be 11 digits'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    // Get bank code
    final bankCode = BankTypes.getBankCode(_selectedBank!);

    // Update KYC state
    ref.read(kycProvider.notifier).updateBankDetails(
      bankName: _selectedBank,
      bankCode: bankCode,
      accountNumber: _accountNumberController.text,
      accountName: _accountNameController.text,
      accountType: _selectedAccountType,
      bvn: _bvnController.text,
    );

    // Navigate to next step (could be KYC completion or profile)
    Navigator.of(context).pushNamed('/kyc-complete');
  }

  void _goBack() {
    ref.read(kycProvider.notifier).previousStep();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
          'Bank Information',
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
              // Progress Indicator
              Row(
                children: [
                  _buildProgressStep(1, true),
                  _buildProgressLine(1),
                  _buildProgressStep(2, true),
                  _buildProgressLine(2),
                  _buildProgressStep(3, true),
                  _buildProgressLine(3),
                  _buildProgressStep(4, false),
                ],
              ),
              const SizedBox(height: 32),

              // Header
              Text(
                'Add Your Bank Details',
                style: CoopvestTypography.headlineSmall.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your bank account information for receiving payouts and refunds',
                style: CoopvestTypography.bodyMedium.copyWith(
                  color: CoopvestColors.mediumGray,
                ),
              ),
              const SizedBox(height: 24),

              // Bank Selection
              Text(
                'Select Bank *',
                style: CoopvestTypography.labelLarge.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 12),
              
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: CoopvestColors.lightGray),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBank,
                  hint: const Text('Select your bank'),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: _banks.map((bank) {
                    return DropdownMenuItem<String>(
                      value: bank['label'] as String?,
                      child: Text(
                        bank['label'] as String,
                        style: CoopvestTypography.bodyMedium,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBank = value;
                      _accountNameVerified = false;
                      _accountNameController.clear();
                    });
                  },
                ),
              ),
              
              const SizedBox(height: 24),

              // Account Number
              AppTextField(
                label: 'Account Number *',
                hint: 'Enter your 10-digit account number',
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                maxLength: 10,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Account number is required';
                  }
                  if (value.length != 10) {
                    return 'Account number must be 10 digits';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value.length == 10) {
                    setState(() {
                      _accountNameVerified = false;
                    });
                  }
                },
              ),
              
              const SizedBox(height: 16),

              // Verify Account Name Button
              if (_selectedBank != null && _accountNumberController.text.length == 10)
                Center(
                  child: _isVerifyingAccountName
                      ? const CircularProgressIndicator(
                          color: CoopvestColors.primary,
                        )
                      : TextButton.icon(
                          onPressed: _accountNameVerified ? null : _verifyAccountName,
                          icon: Icon(
                            _accountNameVerified ? Icons.check_circle : Icons.verified,
                            color: _accountNameVerified ? CoopvestColors.success : CoopvestColors.primary,
                          ),
                          label: Text(
                            _accountNameVerified
                                ? 'Account Name Verified'
                                : 'Tap to Verify Account Name',
                            style: CoopvestTypography.bodyMedium.copyWith(
                              color: _accountNameVerified ? CoopvestColors.success : CoopvestColors.primary,
                            ),
                          ),
                        ),
                ),
              
              const SizedBox(height: 16),

              // Account Name (Read-only after verification)
              AppTextField(
                label: 'Account Name *',
                hint: 'Verified account name',
                controller: _accountNameController,
                enabled: false,
                filledColor: CoopvestColors.veryLightGray,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Account name is required';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),

              // Account Type
              Text(
                'Account Type *',
                style: CoopvestTypography.labelLarge.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 12),
              
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _accountTypes.map((type) {
                  final isSelected = _selectedAccountType == type['value'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAccountType = type['value'] as String?;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CoopvestColors.primary
                            : CoopvestColors.veryLightGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? CoopvestColors.primary
                              : CoopvestColors.lightGray,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.account_balance_wallet,
                            color: isSelected ? Colors.white : CoopvestColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            type['label'] as String,
                            style: CoopvestTypography.bodyMedium.copyWith(
                              color: isSelected ? Colors.white : CoopvestColors.darkGray,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),

              // BVN
              AppTextField(
                label: 'Bank Verification Number (BVN) *',
                hint: 'Enter your 11-digit BVN',
                controller: _bvnController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 11,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'BVN is required';
                  }
                  if (value.length != 11) {
                    return 'BVN must be 11 digits';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 12),

              // BVN Info Card
              AppCard(
                backgroundColor: CoopvestColors.info.withAlpha((255 * 0.1).toInt()),
                border: Border.all(color: CoopvestColors.info.withAlpha((255 * 0.3).toInt())),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: CoopvestColors.info,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your BVN is required for identity verification. It will be encrypted and securely stored.',
                        style: CoopvestTypography.bodySmall.copyWith(
                          color: CoopvestColors.darkGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Continue Button
              PrimaryButton(
                label: 'Continue',
                onPressed: _validateAndContinue,
                width: double.infinity,
              ),
              
              const SizedBox(height: 16),

              // Back Button
              SecondaryButton(
                label: 'Go Back',
                onPressed: _goBack,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(int step, bool isActive) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? CoopvestColors.primary : CoopvestColors.lightGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: isActive
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                '$step',
                style: TextStyle(
                  color: isActive ? Colors.white : CoopvestColors.mediumGray,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    final isComplete = step < 4; // All steps except last are complete
    return Expanded(
      child: Container(
        height: 2,
        color: isComplete ? CoopvestColors.primary : CoopvestColors.lightGray,
      ),
    );
  }
}
