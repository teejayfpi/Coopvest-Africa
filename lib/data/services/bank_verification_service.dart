import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/utils.dart';

/// Result of a successful bank-account verification.
class AccountVerificationResult {
  final String accountName;
  final String accountNumber;
  final String bankCode;

  const AccountVerificationResult({
    required this.accountName,
    required this.accountNumber,
    required this.bankCode,
  });
}

/// Reasons account verification can fail, mapped to user-facing messages.
enum AccountVerificationError {
  invalidFormat,
  notVerified,
  unavailable,
  network,
  unknown,
}

class AccountVerificationException implements Exception {
  final AccountVerificationError reason;
  final String message;

  const AccountVerificationException(this.reason, this.message);

  @override
  String toString() => message;
}

/// Verifies bank account ownership through the backend, which holds the
/// Paystack credentials — no verification API keys ever ship in the app.
class BankVerificationService {
  final ApiClient? _api;

  /// Test seam: replaces the HTTP call so the error-mapping logic can be
  /// exercised without a network.
  final Future<dynamic> Function(String path, Map<String, dynamic> data)?
      _postOverride;

  BankVerificationService(this._api) : _postOverride = null;

  @visibleForTesting
  BankVerificationService.withPoster(
      Future<dynamic> Function(String path, Map<String, dynamic> data) poster)
      : _api = null,
        _postOverride = poster;

  static final RegExp _accountNumberPattern = RegExp(r'^\d{10}$');

  bool isValidAccountNumber(String accountNumber) =>
      _accountNumberPattern.hasMatch(accountNumber.trim());

  Future<AccountVerificationResult> verifyAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final trimmed = accountNumber.trim();
    if (!isValidAccountNumber(trimmed)) {
      throw const AccountVerificationException(
        AccountVerificationError.invalidFormat,
        'Account number must be a valid 10-digit number.',
      );
    }

    try {
      final post = _postOverride ??
          (path, data) => _api!.post(path, data: data);
      final data = await post(
        '/bank-accounts/verify',
        {'bank_code': bankCode, 'account_number': trimmed},
      );

      final accountName =
          data is Map<String, dynamic> ? data['account_name'] as String? : null;
      if (accountName == null || accountName.isEmpty) {
        throw const AccountVerificationException(
          AccountVerificationError.notVerified,
          'Account name could not be retrieved. Please check the bank and account number.',
        );
      }

      return AccountVerificationResult(
        accountName: accountName,
        accountNumber: trimmed,
        bankCode: bankCode,
      );
    } on AccountVerificationException {
      rethrow;
    } on ValidationException catch (e) {
      throw AccountVerificationException(
        AccountVerificationError.invalidFormat,
        e.message,
      );
    } on NetworkException catch (e) {
      throw AccountVerificationException(
        AccountVerificationError.network,
        e.message,
      );
    } on ServerException catch (e) {
      if (e.statusCode == 422) {
        throw const AccountVerificationException(
          AccountVerificationError.notVerified,
          'This account could not be verified. Please check the bank and account number.',
        );
      }
      if (e.statusCode == 503) {
        throw const AccountVerificationException(
          AccountVerificationError.unavailable,
          'Account verification is temporarily unavailable. Please try again later.',
        );
      }
      throw AccountVerificationException(
        AccountVerificationError.unknown,
        e.message,
      );
    } catch (_) {
      throw const AccountVerificationException(
        AccountVerificationError.unknown,
        'This account could not be verified. Please try again.',
      );
    }
  }
}

final bankVerificationServiceProvider =
    Provider<BankVerificationService>((ref) {
  return BankVerificationService(ref.read(apiClientProvider));
});
