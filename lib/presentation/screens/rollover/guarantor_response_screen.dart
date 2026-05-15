import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/rollover_models.dart';
import '../../providers/rollover_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/cards.dart';

/// Screen shown to a GUARANTOR who has received a rollover consent request.
/// They can view the full loan/rollover details then Accept or Decline.
class GuarantorResponseScreen extends ConsumerStatefulWidget {
  final String rolloverId;
  final String guarantorId;

  const GuarantorResponseScreen({
    super.key,
    required this.rolloverId,
    required this.guarantorId,
  });

  @override
  ConsumerState<GuarantorResponseScreen> createState() =>
      _GuarantorResponseScreenState();
}

class _GuarantorResponseScreenState
    extends ConsumerState<GuarantorResponseScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _responded = false;
  bool _accepted = false;
  final TextEditingController _declineReasonController =
      TextEditingController();

  late AnimationController _resultController;
  late Animation<double> _resultScale;
  late Animation<double> _resultFade;

  @override
  void initState() {
    super.initState();
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _resultScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.elasticOut),
    );
    _resultFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _resultController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rolloverProvider.notifier).getRolloverDetails(
            rolloverId: widget.rolloverId,
          );
    });
  }

  @override
  void dispose() {
    _declineReasonController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _respond(bool accept) async {
    if (!accept) {
      final confirmed = await _showDeclineDialog();
      if (!confirmed) return;
    }

    setState(() => _isLoading = true);
    final success = await ref.read(rolloverProvider.notifier).guarantorRespond(
          rolloverId: widget.rolloverId,
          guarantorId: widget.guarantorId,
          accepted: accept,
          reason: accept ? null : _declineReasonController.text.trim(),
        );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          _responded = true;
          _accepted = accept;
        }
      });
      if (success) _resultController.forward();
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(rolloverProvider).error ?? 'An error occurred'),
            backgroundColor: CoopvestColors.error,
          ),
        );
      }
    }
  }

  Future<bool> _showDeclineDialog() async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _DeclineSheet(controller: _declineReasonController),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rolloverProvider);
    final rollover = state.currentRollover;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Rollover Consent',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: state.isLoading && rollover == null
          ? const Center(child: CircularProgressIndicator())
          : _responded
              ? _buildResultView()
              : _buildConsentView(context, rollover),
    );
  }

  // ── Result view after responding ─────────────────────────────────────────

  Widget _buildResultView() {
    final color = _accepted ? CoopvestColors.success : CoopvestColors.error;
    final icon = _accepted ? Icons.check_rounded : Icons.close_rounded;
    final title = _accepted ? 'Consent Granted' : 'Request Declined';
    final message = _accepted
        ? 'Thank you! Your consent has been recorded. The borrower will be notified.'
        : 'You have declined this rollover request. The borrower will be notified and may appoint a replacement guarantor.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: AnimatedBuilder(
          animation: _resultController,
          builder: (context, child) => Opacity(
            opacity: _resultFade.value,
            child: Transform.scale(
              scale: _resultScale.value,
              child: child,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, size: 54, color: Colors.white),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: context.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              PrimaryButton(
                label: 'Back to Home',
                onPressed: () =>
                    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false),
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Consent view ──────────────────────────────────────────────────────────

  Widget _buildConsentView(BuildContext context, LoanRollover? rollover) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B3A6B).withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1B3A6B).withOpacity(0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF1B3A6B), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You have been selected as a guarantor for the loan rollover request below. Please review the details carefully before responding.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (rollover != null) ...[
            // Borrower card
            _SectionLabel(label: 'Borrower'),
            const SizedBox(height: 8),
            AppCard(
              backgroundColor: context.cardBackground,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        CoopvestColors.primary.withOpacity(0.12),
                    radius: 24,
                    child: Text(
                      rollover.memberName.isNotEmpty
                          ? rollover.memberName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: CoopvestColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rollover.memberName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        rollover.memberPhone,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Loan details
            _SectionLabel(label: 'Original Loan'),
            const SizedBox(height: 8),
            AppCard(
              backgroundColor: context.cardBackground,
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Principal Amount',
                    value:
                        'NGN ${_fmt(rollover.originalPrincipal)}',
                    bold: true,
                  ),
                  _DetailRow(
                    label: 'Amount Repaid',
                    value:
                        'NGN ${_fmt(rollover.totalRepaid)} (${rollover.repaymentPercentage.toStringAsFixed(0)}%)',
                    valueColor: CoopvestColors.success,
                  ),
                  _DetailRow(
                    label: 'Outstanding Balance',
                    value: 'NGN ${_fmt(rollover.outstandingBalance)}',
                    valueColor: CoopvestColors.error,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // New terms
            _SectionLabel(label: 'Requested Rollover Terms'),
            const SizedBox(height: 8),
            AppCard(
              backgroundColor: context.cardBackground,
              child: Column(
                children: [
                  _DetailRow(
                    label: 'New Tenure',
                    value: '${rollover.newTenure} months',
                    bold: true,
                  ),
                  _DetailRow(
                    label: 'New Monthly Repayment',
                    value: 'NGN ${_fmt(rollover.newMonthlyRepayment)}',
                  ),
                  _DetailRow(
                    label: 'Total New Repayment',
                    value: 'NGN ${_fmt(rollover.newTotalRepayment)}',
                  ),
                  _DetailRow(
                    label: 'Interest Rate',
                    value: '${rollover.newInterestRate.toStringAsFixed(1)}% p.a.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Consent deadline
            if (rollover.guarantorConsentDeadline != null) ...[
              _SectionLabel(label: 'Consent Deadline'),
              const SizedBox(height: 8),
              AppCard(
                backgroundColor: CoopvestColors.warning.withOpacity(0.08),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: CoopvestColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _formatDeadline(rollover.guarantorConsentDeadline!),
                      style: const TextStyle(
                        color: CoopvestColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Responsibility notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CoopvestColors.error.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CoopvestColors.error.withOpacity(0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: CoopvestColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'By accepting, you agree to act as a guarantor for this rollover. If the borrower defaults, you may be liable for the outstanding balance.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Text('Unable to load rollover details. Please try again.'),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => _respond(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: CoopvestColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(
                      color: CoopvestColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Accept',
                  onPressed: () async {
                    if (!_isLoading) await _respond(true);
                  },
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _fmt(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final dec = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '${buffer.toString()}.$dec';
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return 'Respond by ${deadline.day}/${deadline.month}/${deadline.year} (${diff.inDays}d left)';
    return 'Respond within ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }
}

// ── Decline bottom sheet ────────────────────────────────────────────────────

class _DeclineSheet extends StatelessWidget {
  final TextEditingController controller;
  const _DeclineSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Decline This Request?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Please let the borrower know why you are declining (optional).',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for declining (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CoopvestColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? const Color(0xFF1B3A6B),
            ),
          ),
        ],
      ),
    );
  }
}
