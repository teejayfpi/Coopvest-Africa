import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/network/api_client.dart';
import 'package:coopvest_mobile/core/utils/utils.dart';
import 'package:coopvest_mobile/data/services/bank_verification_service.dart';

void main() {
  final service = BankVerificationService(ApiClient());

  group('BankVerificationService.isValidAccountNumber', () {
    test('accepts a 10-digit number', () {
      expect(service.isValidAccountNumber('0123456789'), isTrue);
    });

    test('accepts surrounding whitespace', () {
      expect(service.isValidAccountNumber('  0123456789 '), isTrue);
    });

    test('rejects numbers that are too short or too long', () {
      expect(service.isValidAccountNumber('012345678'), isFalse);
      expect(service.isValidAccountNumber('01234567890'), isFalse);
    });

    test('rejects non-numeric input', () {
      expect(service.isValidAccountNumber('01234abcde'), isFalse);
      expect(service.isValidAccountNumber(''), isFalse);
    });
  });

  group('BankVerificationService.verifyAccount format validation', () {
    test('rejects an invalid account number before any network call', () {
      expect(
        () => service.verifyAccount(bankCode: '044', accountNumber: '123'),
        throwsA(
          isA<AccountVerificationException>()
              .having((e) => e.reason, 'reason',
                  AccountVerificationError.invalidFormat)
              .having((e) => e.message, 'message',
                  'Account number must be a valid 10-digit number.'),
        ),
      );
    });

    test('rejects an empty account number', () {
      expect(
        () => service.verifyAccount(bankCode: '044', accountNumber: '   '),
        throwsA(isA<AccountVerificationException>().having(
            (e) => e.reason, 'reason', AccountVerificationError.invalidFormat)),
      );
    });
  });

  group('BankVerificationService.verifyAccount response handling', () {
    test('returns the resolved account name on success', () async {
      final svc = BankVerificationService.withPoster((path, data) async => {
            'success': true,
            'account_name': 'AYANLOWO TEMILOLUWA',
          });
      final result = await svc.verifyAccount(
          bankCode: '044', accountNumber: '0123456789');
      expect(result.accountName, 'AYANLOWO TEMILOLUWA');
      expect(result.accountNumber, '0123456789');
      expect(result.bankCode, '044');
    });

    test('sends the trimmed account number and bank code to the backend',
        () async {
      Map<String, dynamic>? sent;
      final svc = BankVerificationService.withPoster((path, data) async {
        sent = data;
        return {'success': true, 'account_name': 'TEST USER'};
      });
      await svc.verifyAccount(bankCode: '999992', accountNumber: ' 0123456789 ');
      expect(sent, {'bank_code': '999992', 'account_number': '0123456789'});
    });

    test('rejects when the backend returns no account name', () {
      final svc = BankVerificationService.withPoster((path, data) async => {
            'success': true,
          });
      expect(
        () => svc.verifyAccount(bankCode: '044', accountNumber: '0123456789'),
        throwsA(isA<AccountVerificationException>()
            .having((e) => e.reason, 'reason',
                AccountVerificationError.notVerified)
            .having((e) => e.message, 'message',
                'Account name could not be retrieved. Please check the bank and account number.')),
      );
    });

    test('maps a 422 to "account could not be verified"', () {
      final svc = BankVerificationService.withPoster(
          (path, data) async => throw ServerException(
              'Account number could not be resolved',
              statusCode: 422));
      expect(
        () => svc.verifyAccount(bankCode: '044', accountNumber: '0123456789'),
        throwsA(isA<AccountVerificationException>()
            .having((e) => e.reason, 'reason',
                AccountVerificationError.notVerified)
            .having((e) => e.message, 'message',
                'This account could not be verified. Please check the bank and account number.')),
      );
    });

    test('maps a 503 to "verification temporarily unavailable"', () {
      final svc = BankVerificationService.withPoster((path, data) async =>
          throw ServerException('Account verification is not configured',
              statusCode: 503));
      expect(
        () => svc.verifyAccount(bankCode: '044', accountNumber: '0123456789'),
        throwsA(isA<AccountVerificationException>()
            .having((e) => e.reason, 'reason',
                AccountVerificationError.unavailable)
            .having((e) => e.message, 'message',
                'Account verification is temporarily unavailable. Please try again later.')),
      );
    });

    test('maps network failures to a connection message', () {
      final svc = BankVerificationService.withPoster((path, data) async =>
          throw NetworkException(
              'Unable to connect to the server. Please check your internet connection.'));
      expect(
        () => svc.verifyAccount(bankCode: '044', accountNumber: '0123456789'),
        throwsA(isA<AccountVerificationException>()
            .having((e) => e.reason, 'reason', AccountVerificationError.network)
            .having((e) => e.message, 'message',
                'Unable to connect to the server. Please check your internet connection.')),
      );
    });

    test('maps unexpected exceptions to a generic safe message', () {
      final svc = BankVerificationService.withPoster(
          (path, data) async => throw StateError('boom'));
      expect(
        () => svc.verifyAccount(bankCode: '044', accountNumber: '0123456789'),
        throwsA(isA<AccountVerificationException>()
            .having((e) => e.reason, 'reason', AccountVerificationError.unknown)
            .having((e) => e.message, 'message',
                'This account could not be verified. Please try again.')),
      );
    });
  });
}
