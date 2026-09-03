import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/bank_directory.dart';
import '../../../data/models/kyc_models.dart';
import '../../../data/services/bank_verification_service.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/kyc_provider.dart';
import '../../../presentation/widgets/common/bank_selector_field.dart';
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

  BankOption? _selectedBank;
  String? _selectedAccountType;

  final List<Map<String, dynamic>> _accountTypes = BankAccountTypes.types;

  bool _accountNameVerified = false;
  bool _manualEntry = false;
  bool _isVerifyingAccountName = false;

  @override
  void initState() {
    super.initState();
    _accountNumberController = TextEditingController();
    _accountNameController = TextEditingController();
    _bvnController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(kycProvider, (prev, next) {
        if (next.status == KYCStatus.loaded &&
            (prev == null || prev.status != KYCStatus.loaded)) {
          _loadExistingAndMaybeSkip();
        }
      });
      _loadExistingAndMaybeSkip();
    });
  }

  /// Pre-fill from an existing KYC submission and skip this step entirely if
  /// it's already complete.
  void _loadExistingAndMaybeSkip() {
    final kycState = ref.read(kycProvider);
    if (kycState.status == KYCStatus.initial ||
        kycState.status == KYCStatus.loading) {
      ref.read(kycProvider.notifier).initializeKYC();
      return;
    }

    final sub = kycState.submission;
    if (sub == null) return;

    setState(() {
      final bankName = sub.bankName;
      final bankCode = sub.bankCode ?? '';
      _selectedBank = bankName != null
          ? BankOption(name: bankName, code: bankCode)
          : null;
      _accountNumberController.text = sub.accountNumber ?? '';
      _accountNameController.text = sub.accountName ?? '';
      _accountNameVerified = (sub.accountName ?? '').isNotEmpty;
      _selectedAccountType = sub.accountType;
      _bvnController.text = sub.bvn ?? '';
    });

    if (sub.bankName != null &&
        sub.accountNumber != null &&
        sub.accountName != null &&
        sub.accountType != null &&
        sub.bvn != null) {
      // Bank step complete — go to success.
      Navigator.of(context).pushReplacementNamed('/kyc-complete');
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
    if (_selectedBank == null) {
      _showError('Please select your bank');
      return;
    }
    if (_accountNumberController.text.trim().isEmpty) {
      _showError('Please enter your account number');
      return;
    }

    setState(() {
      _isVerifyingAccountName = true;
    });

    try {
      // Resolve the account holder name via the backend verification
      // service (Paystack bank-resolve, credentials stay server-side).
      final result = await ref
          .read(bankVerificationServiceProvider)
          .verifyAccount(
            bankCode: _selectedBank!.code,
            accountNumber: _accountNumberController.text,
          );

      if (!mounted) return;
      setState(() => _isVerifyingAccountName = false);

      // The member must review and confirm the resolved account name before
      // it is accepted.
      final confirmed = await _confirmAccountName(result.accountName);
      if (!mounted) return;
      if (confirmed == true) {
        setState(() {
          _accountNameVerified = true;
          _accountNameController.text = result.accountName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account verified successfully'),
            backgroundColor: CoopvestColors.success,
          ),
        );
      } else {
        setState(() {
          _accountNameVerified = false;
          _accountNameController.clear();
        });
        _showError(
          'The account name does not match the information provided. Please check the bank and account number.',
        );
      }
    } on AccountVerificationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingAccountName = false;
        _accountNameVerified = false;
      });
      // When verification itself is down (or the network is), members would
      // otherwise be hard-blocked from completing registration — offer manual
      // entry instead. Genuine "account not found" errors still block.
      if (e.reason == AccountVerificationError.unavailable ||
          e.reason == AccountVerificationError.network) {
        final manual = await _offerManualEntry();
        if (!mounted) return;
        if (manual == true) {
          setState(() => _manualEntry = true);
          return;
        }
      }
      _showError(e.message);
    }
  }

  Future<bool?> _offerManualEntry() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verification Unavailable'),
        content: const Text(
          'We could not verify this account right now. You can enter the '
          'account name manually and continue. Make sure the name matches '
          'the bank account holder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Try again'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CoopvestColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enter manually'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmAccountName(String accountName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Account Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This account is registered to:'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CoopvestColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CoopvestColors.success),
              ),
              child: Text(
                accountName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Is this your account?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, go back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CoopvestColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, this is mine'),
          ),
        ],
      ),
    );
  }

  void _validateAndContinue() {
    if (_selectedBank == null) {
      _showError('Please select your bank');
      return;
    }
    if (_accountNumberController.text.length != 10) {
      _showError('Account number must be 10 digits');
      return;
    }
    if (!_accountNameVerified && !_manualEntry) {
      _showError('Please verify your account name');
      return;
    }
    if (_manualEntry && _accountNameController.text.trim().isEmpty) {
      _showError('Please enter the account name');
      return;
    }
    if (_selectedAccountType == null) {
      _showError('Please select your account type');
      return;
    }
    if (_bvnController.text.trim().isEmpty) {
      _showError('Please enter your BVN');
      return;
    }

    // Save bank details (incl. BVN) to KYC state
    final kycNotifier = ref.read(kycProvider.notifier);
    kycNotifier.updateBankDetails(
      bankName: _selectedBank!.name,
      bankCode: _selectedBank!.code,
      accountNumber: _accountNumberController.text,
      accountName: _accountNameController.text,
      accountType: _selectedAccountType,
      bvn: _bvnController.text.trim(),
    );

    // Re-submit the (now complete) KYC record so bank/BVN details persist, then
    // refresh the auth state so the KYC entry hides for already-submitted users.
    _submitAndContinue();
  }

  Future<void> _submitAndContinue() async {
    try {
      await ref.read(kycProvider.notifier).submitKYC();
      ref.read(authProvider.notifier).markKycSubmitted();
    } catch (_) {
      // Non-fatal: the selfie step already submitted the KYC core; bank
      // details are saved locally on the submission. Proceed to success.
    }
    if (mounted) Navigator.of(context).pushReplacementNamed('/kyc-complete');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: CoopvestColors.error),
    );
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: _goBack,
        ),
        title: Text(
          'Bank Information',
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

              Text(
                'Add Your Bank Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your bank account information for receiving payouts and refunds',
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 24),

              BankSelectorField(
                value: _selectedBank,
                onChanged: (bank) {
                  setState(() {
                    _selectedBank = bank;
                    _accountNameVerified = false;
                    _manualEntry = false;
                    _accountNameController.clear();
                  });
                },
              ),
              const SizedBox(height: 20),

              AppTextField(
                label: 'Account Number *',
                hint: 'Enter 10-digit account number',
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                onChanged: (val) {
                  if (_accountNameVerified || _manualEntry) {
                    setState(() {
                      _accountNameVerified = false;
                      _manualEntry = false;
                      _accountNameController.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              if (!_accountNameVerified && !_manualEntry)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isVerifyingAccountName
                        ? null
                        : _verifyAccountName,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CoopvestColors.primary,
                      side: const BorderSide(color: CoopvestColors.primary),
                    ),
                    child: _isVerifyingAccountName
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Verifying account details…'),
                            ],
                          )
                        : const Text('Verify Account'),
                  ),
                ),

              if (_accountNameVerified || _manualEntry)
                AppTextField(
                  label: _manualEntry ? 'Account Name *' : 'Account Name',
                  hint: _manualEntry
                      ? 'Enter the name on the bank account'
                      : null,
                  controller: _accountNameController,
                  readOnly: !_manualEntry,
                  filled: true,
                ),
              const SizedBox(height: 20),

              AppDropdown<String>(
                label: 'Account Type *',
                hint: 'Select account type',
                value: _selectedAccountType,
                items: _accountTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'] as String?,
                    child: Text(type['label'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAccountType = value;
                  });
                },
              ),
              const SizedBox(height: 20),

              AppTextField(
                label: 'BVN *',
                hint: 'Enter your Bank Verification Number',
                controller: _bvnController,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 40),

              PrimaryButton(
                label: 'Continue',
                onPressed: _validateAndContinue,
                width: double.infinity,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(int step, bool isCompleted) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isCompleted ? CoopvestColors.primary : context.dividerColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                '$step',
                style: TextStyle(
                  color: context.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    return Expanded(child: Container(height: 2, color: context.dividerColor));
  }
}
