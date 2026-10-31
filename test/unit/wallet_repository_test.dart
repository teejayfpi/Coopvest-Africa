import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coopvest_mobile/core/network/api_client.dart';
import 'package:coopvest_mobile/presentation/providers/wallet_provider.dart';

/// Returns whatever the test hands it, or throws if the handler throws.
class _StubApiClient extends ApiClient {
  final dynamic Function(String path) handler;

  _StubApiClient(this.handler);

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return handler(path);
  }
}

void main() {
  group('WalletRepository.getWallet', () {
    test('maps the balance response into a Wallet', () async {
      final repo = WalletRepository(_StubApiClient((path) {
        expect(path, '/wallet/balance');
        return <String, dynamic>{
          'id': 'w1',
          'user_id': 'u1',
          'balance': 12500,
          'total_savings': 8000,
          'pending_contributions': 1500,
          'available_for_withdrawal': 11000,
        };
      }));

      final wallet = await repo.getWallet();

      expect(wallet.balance, 12500);
      expect(wallet.totalSavings, 8000);
      expect(wallet.pendingContributions, 1500);
      expect(wallet.availableForWithdrawal, 11000);
    });

    test('throws when the balance cannot be read, rather than reporting zero',
        () async {
      // The old implementation caught this and returned a wallet of zeros, so
      // the dashboard showed "₦0.00 available" and the withdrawal screen
      // refused every amount. A failed fetch must stay a failure.
      final repo = WalletRepository(_StubApiClient((_) {
        throw DioException(
          requestOptions: RequestOptions(path: '/wallet/balance'),
          type: DioExceptionType.connectionError,
          message: 'offline',
        );
      }));

      await expectLater(repo.getWallet(), throwsA(isA<DioException>()));
    });
  });
}
