import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/terms_acceptance_store.dart';
import '../../providers/kyc_provider.dart';
import '../../widgets/common/buttons.dart';
import '../../widgets/common/selfie_capture_field.dart';

/// Final step of the sign-up flow: selfie + preferred monthly savings, taken
/// immediately before the registration payment.
///
/// WHY THIS SCREEN EXISTS
/// ----------------------
/// Both were originally collected inside the 8-step profile wizard
/// (`/register-step3`), which the email sign-up path never reaches: it goes
/// sign up -> verify -> contribution type -> payment. So on the shortened flow
/// members were never asked for either, even though both are required for the
/// app to work properly:
///
///   * the selfie is the identity photo used for KYC review and as the profile
///     avatar, and
///   * `monthly_amount` seeds `contribution_plans.current_monthly_amount`, the
///     single source of truth for "Your obligations this month".
///
/// Putting them here keeps the flow short and puts both before the payment,
/// which is where the member is already committing money.
class SignupDetailsScreen extends ConsumerStatefulWidget {
  /// Registration data carried through the flow.
  final Map<String, String> registrationData;

  const SignupDetailsScreen({super.key, required this.registrationData});

  @override
  ConsumerState<SignupDetailsScreen> createState() =>
      _SignupDetailsScreenState();
}

class _SignupDetailsScreenState extends ConsumerState<SignupDetailsScreen> {
  File? _selfie;
  bool _uploadingSelfie = false;
  bool _selfieUploaded = false;

  double _monthlyAmount = 5000;
  final _customCtrl = TextEditingController();
  bool _showCustom = false;
  String? _amountError;

  /// Minimum monthly contribution. Mirrors the floor enforced by the
  /// contribution wizard and the backend's plan seeding.
  static const double _minMonthly = 5000;

  static const List<double> _presets = [5000, 10000, 20000, 50000];

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadSelfie(File file) async {
    setState(() {
      _uploadingSelfie = true;
      _selfieUploaded = false;
    });
    try {
      // Uploads through /kyc/upload, which writes the URL onto the kyc row and
      // syncs the member's profile picture. Carrying a local device path
      // forward would be dropped, and `/data/user/0/...` is meaningless to the
      // backend.
      await ref.read(kycProvider.notifier).uploadSelfie(file.path);
      if (!mounted) return;
      setState(() => _selfieUploaded = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not upload your selfie: $e'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingSelfie = false);
    }
  }

  String _fmt(double v) =>
      v.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );

  Future<void> _continue() async {
    if (_selfie == null || !_selfieUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your selfie before continuing'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }
    if (_monthlyAmount < _minMonthly) {
      setState(() => _amountError =
          'Minimum monthly savings is \u20a6${_fmt(_minMonthly)}');
      return;
    }

    setState(() => _amountError = null);

    // Persist the chosen amount so the payment step and KYC can both see it.
    // The backend seeds contribution_plans from `monthly_amount`, so this is
    // what drives "Your obligations this month".
    await TermsAcceptanceStore.saveMonthlyAmount(_monthlyAmount);

    final updated = Map<String, String>.from(widget.registrationData)
      ..['monthly_amount'] = _monthlyAmount.toStringAsFixed(0);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      '/account-activation',
      arguments: updated,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.scaffoldBackground,
        automaticallyImplyLeading: false,
        title: Text(
          'Almost done',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Selfie ──────────────────────────────────────────────────
              Text(
                'Add your selfie',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: CoopvestShape.gapXs),
              Text(
                'Used to confirm it is really you. It is never shared.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: CoopvestShape.gapLg),
              SelfieCaptureField(
                file: _selfie,
                onCaptured: (f) {
                  setState(() => _selfie = f);
                  _uploadSelfie(f);
                },
                onCleared: () => setState(() {
                  _selfie = null;
                  _selfieUploaded = false;
                }),
              ),
              if (_uploadingSelfie) ...[
                const SizedBox(height: CoopvestShape.gapSm),
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: CoopvestShape.gapSm),
                    Text(
                      'Uploading your selfie…',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ] else if (_selfieUploaded) ...[
                const SizedBox(height: CoopvestShape.gapSm),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 15,
                      color: CoopvestColors.successText,
                    ),
                    const SizedBox(width: CoopvestShape.gapSm),
                    Text(
                      'Selfie uploaded',
                      style: TextStyle(
                        fontSize: 12,
                        color: CoopvestColors.successText,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: CoopvestShape.gapXl),
              Divider(color: context.dividerColor),
              const SizedBox(height: CoopvestShape.gapXl),

              // ── Monthly savings ─────────────────────────────────────────
              Text(
                'Preferred monthly savings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: CoopvestShape.gapXs),
              Text(
                'You can change this later from your dashboard.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: CoopvestShape.gapLg),
              Wrap(
                spacing: CoopvestShape.gapSm,
                runSpacing: CoopvestShape.gapSm,
                children: [
                  ..._presets.map((amt) {
                    final selected =
                        !_showCustom && _monthlyAmount == amt;
                    return _AmountChip(
                      label: '\u20a6${_fmt(amt)}',
                      selected: selected,
                      onTap: () => setState(() {
                        _monthlyAmount = amt;
                        _showCustom = false;
                        _amountError = null;
                      }),
                    );
                  }),
                  _AmountChip(
                    label: 'Custom',
                    selected: _showCustom,
                    onTap: () => setState(() => _showCustom = true),
                  ),
                ],
              ),
              if (_showCustom) ...[
                const SizedBox(height: CoopvestShape.gapMd),
                TextField(
                  controller: _customCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixText: '\u20a6 ',
                    hintText: 'Min \u20a6${_fmt(_minMonthly)}',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(CoopvestShape.chipRadius),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (v) {
                    final val = double.tryParse(v);
                    setState(() {
                      _monthlyAmount = val ?? 0;
                      _amountError = null;
                    });
                  },
                ),
              ],
              if (_amountError != null) ...[
                const SizedBox(height: CoopvestShape.gapSm),
                Text(
                  _amountError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CoopvestColors.errorText,
                  ),
                ),
              ],

              const SizedBox(height: CoopvestShape.gapXl),

              // ── What happens next ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CoopvestColors.iconTintGreen,
                  borderRadius:
                      BorderRadius.circular(CoopvestShape.cardRadius),
                  border: Border.all(color: CoopvestColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(context, 'Registration fee (one-time)',
                        '\u20a65,000'),
                    const SizedBox(height: CoopvestShape.gapXs),
                    _row(context, 'Your monthly savings',
                        '\u20a6${_fmt(_monthlyAmount)}'),
                  ],
                ),
              ),

              const SizedBox(height: CoopvestShape.gapXl),
              PrimaryButton(
                label: 'Continue to payment',
                onPressed: _continue,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Selectable amount pill.
class _AmountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AmountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? CoopvestColors.iconTintGreen
              : context.cardBackground,
          borderRadius: BorderRadius.circular(CoopvestShape.chipRadius),
          border: Border.all(
            color: selected
                ? CoopvestColors.primary
                : CoopvestColors.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? CoopvestColors.primary : context.textPrimary,
          ),
        ),
      ),
    );
  }
}