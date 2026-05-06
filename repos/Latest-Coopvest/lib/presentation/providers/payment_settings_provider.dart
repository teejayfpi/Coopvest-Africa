import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the bank account details shown on the deposit screen.
/// In production these should be fetched from the admin API.
class PaymentAccountDetails {
  final String bank;
  final String accountName;
  final String accountNumber;

  const PaymentAccountDetails({
    required this.bank,
    required this.accountName,
    required this.accountNumber,
  });

  PaymentAccountDetails copyWith({
    String? bank,
    String? accountName,
    String? accountNumber,
  }) {
    return PaymentAccountDetails(
      bank: bank ?? this.bank,
      accountName: accountName ?? this.accountName,
      accountNumber: accountNumber ?? this.accountNumber,
    );
  }
}

/// Default payment account — updated by super admin via the admin dashboard.
const _defaultPaymentAccount = PaymentAccountDetails(
  bank: 'Opay',
  accountName: 'Ayanlowo Olatunji Ayobami',
  accountNumber: '7038193753',
);

class PaymentSettingsNotifier extends StateNotifier<PaymentAccountDetails> {
  PaymentSettingsNotifier() : super(_defaultPaymentAccount);

  /// Called once on startup to load settings from the API.
  /// Falls back to defaults if the API is unreachable.
  Future<void> loadFromApi() async {
    try {
      // TODO: replace with real API call, e.g.:
      // final resp = await apiClient.get('/admin/payment-settings');
      // state = PaymentAccountDetails(
      //   bank: resp['bank'], accountName: resp['account_name'], accountNumber: resp['account_number']);
    } catch (_) {
      // Keep defaults on error
    }
  }

  void update({String? bank, String? accountName, String? accountNumber}) {
    state = state.copyWith(
      bank: bank,
      accountName: accountName,
      accountNumber: accountNumber,
    );
  }
}

final paymentSettingsProvider =
    StateNotifierProvider<PaymentSettingsNotifier, PaymentAccountDetails>(
  (ref) => PaymentSettingsNotifier(),
);
