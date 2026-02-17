import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';

/// Guarantor Verification Screen
class GuarantorVerificationScreen extends StatefulWidget {
  final String loanId;
  final String borrowerName;
  final double loanAmount;
  final String loanType;
  final int loanTenor;
  final String guarantorId;
  final String guarantorName;
  final String? guarantorPhone;

  const GuarantorVerificationScreen({
    super.key,
    required this.loanId,
    required this.borrowerName,
    required this.loanAmount,
    required this.loanType,
    required this.loanTenor,
    required this.guarantorId,
    required this.guarantorName,
    this.guarantorPhone,
  });

  @override
  State<GuarantorVerificationScreen> createState() => _GuarantorVerificationScreenState();
}

class _GuarantorVerificationScreenState extends State<GuarantorVerificationScreen> {
  String _verificationStatus = 'review';
  bool _isProcessing = false;
  bool _agreedToTerms = false;
  double get _guarantorLiability => widget.loanAmount / 3;

  Future<void> _confirmConsent() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please read and accept the liability terms'), backgroundColor: CoopvestColors.error));
      return;
    }
    setState(() { _isProcessing = true; _verificationStatus = 'processing'; });
    try {
      await Future.delayed(const Duration(seconds: 2));
      setState(() { _verificationStatus = 'confirmed'; _isProcessing = false; });
      _showSuccessDialog();
    } catch (e) {
      setState(() { _verificationStatus = 'consent'; _isProcessing = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to confirm guarantee: $e'), backgroundColor: CoopvestColors.error));
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardBackground,
        title: Row(children: [const Icon(Icons.check_circle, color: CoopvestColors.success, size: 32), const SizedBox(width: 12), Text('Guarantee Confirmed', style: TextStyle(color: context.textPrimary))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your guarantee has been successfully recorded.', textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: CoopvestColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text('Your Liability Share', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                  const SizedBox(height: 8),
                  Text('₦${_guarantorLiability.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: CoopvestColors.primary)),
                ],
              ),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); }, child: const Text('Done'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: context.iconPrimary), onPressed: () => Navigator.of(context).pop()),
        title: Text('Guarantee Consent', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressStepper(context),
              const SizedBox(height: 24),
              if (_verificationStatus == 'review') _buildReviewScreen(context)
              else if (_verificationStatus == 'consent') _buildConsentScreen(context)
              else _buildProcessingScreen(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStepper(BuildContext context) {
    final steps = ['Review', 'Consent', 'Confirm'];
    int currentStep = _verificationStatus == 'review' ? 0 : (_verificationStatus == 'consent' ? 1 : 2);
    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) return Expanded(child: Container(height: 2, color: index ~/ 2 < currentStep ? CoopvestColors.primary : context.dividerColor));
        final stepIndex = index ~/ 2;
        final isActive = stepIndex <= currentStep;
        return Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: isActive ? CoopvestColors.primary : context.dividerColor, shape: BoxShape.circle),
          child: Center(child: stepIndex < currentStep ? const Icon(Icons.check, color: Colors.white, size: 18) : Text('${stepIndex + 1}', style: TextStyle(color: isActive ? Colors.white : context.textSecondary, fontWeight: FontWeight.bold))),
        );
      }),
    );
  }

  Widget _buildReviewScreen(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          backgroundColor: context.cardBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [const Icon(Icons.description, color: CoopvestColors.primary), const SizedBox(width: 8), Text('Loan Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary))]),
              const SizedBox(height: 16),
              _buildSummaryRow(context, 'Borrower:', widget.borrowerName),
              _buildSummaryRow(context, 'Loan Type:', widget.loanType),
              _buildSummaryRow(context, 'Amount:', '₦${widget.loanAmount.toStringAsFixed(2)}'),
              _buildSummaryRow(context, 'Tenor:', '${widget.loanTenor} months'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        PrimaryButton(label: 'Continue to Consent', onPressed: () => setState(() => _verificationStatus = 'consent'), width: double.infinity),
      ],
    );
  }

  Widget _buildConsentScreen(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Liability Terms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.dividerColor)),
          child: Text('By proceeding, you agree to be liable for 1/3 of the loan amount in case of default.', style: TextStyle(color: context.textSecondary, height: 1.5)),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Checkbox(value: _agreedToTerms, onChanged: (v) => setState(() => _agreedToTerms = v ?? false), activeColor: CoopvestColors.primary),
            Expanded(child: Text('I accept the liability terms', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold))),
          ],
        ),
        const SizedBox(height: 32),
        PrimaryButton(label: 'Confirm Guarantee', onPressed: _confirmConsent, isLoading: _isProcessing, width: double.infinity),
      ],
    );
  }

  Widget _buildProcessingScreen(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 48),
          const CircularProgressIndicator(color: CoopvestColors.primary),
          const SizedBox(height: 24),
          Text('Processing your guarantee...', style: TextStyle(color: context.textPrimary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.textSecondary)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
        ],
      ),
    );
  }
}
