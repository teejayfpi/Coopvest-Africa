import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/utils.dart';
import '../../data/models/wallet_models.dart';

/// Wallet Repository Provider
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WalletRepository(apiClient);
});

/// Wallet Repository
class WalletRepository {
  final ApiClient _apiClient;

  WalletRepository(this._apiClient);

  /// Get wallet
  Future<Wallet> getWallet() async {
    try {
      final response = await _apiClient.get('/wallet/balance');
      // Backend returns { success: true, balance: ..., recentTransactions: ... }
      // We need to map this to the Wallet model
      if (response is Map<String, dynamic>) {
        return Wallet(
          id: '',
          userId: '',
          balance: (response['balance'] as num?)?.toDouble() ?? 0.0,
          totalContributions: 0.0,
          pendingContributions: 0.0,
          availableForWithdrawal: (response['balance'] as num?)?.toDouble() ?? 0.0,
          updatedAt: response['lastUpdated'] != null ? DateTime.parse(response['lastUpdated'] as String) : DateTime.now(),
        );
      }
      return Wallet.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      logger.e('Get wallet error: $e');
      rethrow;
    }
  }

  /// Get transactions
  Future<List<Transaction>> getTransactions({
    int page = 1,
    int pageSize = 20,
    String? type,
    String? status,
  }) async {
    try {
      final response = await _apiClient.get(
        '/wallet/transactions',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (type != null) 'type': type,
          if (status != null) 'status': status,
        },
      );

      final data = response as Map<String, dynamic>;
      final transactions = (data['transactions'] as List? ?? [])
          .map((item) => Transaction.fromJson(item as Map<String, dynamic>))
          .toList();

      return transactions;
    } catch (e) {
      logger.e('Get transactions error: $e');
      rethrow;
    }
  }

  /// Make contribution
  Future<Transaction> makeContribution(double amount) async {
    try {
      final response = await _apiClient.post(
        '/wallet/contribute',
        data: {'amount': amount},
      );

      return Transaction.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      logger.e('Make contribution error: $e');
      rethrow;
    }
  }

  /// Get contributions
  Future<List<Contribution>> getContributions({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/wallet/contributions',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );

      final data = response as Map<String, dynamic>;
      final contributions = (data['data'] as List? ?? [])
          .map((item) => Contribution.fromJson(item as Map<String, dynamic>))
          .toList();

      return contributions;
    } catch (e) {
      logger.e('Get contributions error: $e');
      rethrow;
    }
  }

  /// Generate statement
  Future<String> generateStatement({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _apiClient.post(
        '/wallet/statement',
        data: {
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
        },
      );

      return response['statement_url'] as String? ?? '';
    } catch (e) {
      logger.e('Generate statement error: $e');
      rethrow;
    }
  }

  /// Get transaction receipt
  Future<String> getTransactionReceipt(String transactionId) async {
    try {
      final response = await _apiClient.get(
        '/wallet/transactions/$transactionId/receipt',
      );

      return response['receipt_url'] as String? ?? '';
    } catch (e) {
      logger.e('Get transaction receipt error: $e');
      rethrow;
    }
  }
}

/// Wallet Notifier
class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository _walletRepository;

  WalletNotifier(this._walletRepository) : super(const WalletState());

  /// Load wallet
  Future<void> loadWallet() async {
    state = state.copyWith(status: WalletStatus.loading);
    try {
      final wallet = await _walletRepository.getWallet();
      state = state.copyWith(
        status: WalletStatus.loaded,
        wallet: wallet,
      );
    } catch (e) {
      logger.e('Load wallet error: $e');
      state = state.copyWith(
        status: WalletStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Load transactions
  Future<void> loadTransactions({
    int page = 1,
    int pageSize = 20,
    String? type,
    String? status,
  }) async {
    state = state.copyWith(status: WalletStatus.loading);
    try {
      final transactions = await _walletRepository.getTransactions(
        page: page,
        pageSize: pageSize,
        type: type,
        status: status,
      );

      state = state.copyWith(
        status: WalletStatus.loaded,
        transactions: transactions,
      );
    } catch (e) {
      logger.e('Load transactions error: $e');
      state = state.copyWith(
        status: WalletStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Make contribution
  Future<void> makeContribution({
    required double amount,
    String? description,
  }) async {
    state = state.copyWith(status: WalletStatus.loading);
    try {
      final transaction = await _walletRepository.makeContribution(amount);

      // Reload wallet
      await loadWallet();

      // Add transaction to list
      state = state.copyWith(
        status: WalletStatus.loaded,
        transactions: [transaction, ...state.transactions],
      );
    } catch (e) {
      logger.e('Make contribution error: $e');
      state = state.copyWith(
        status: WalletStatus.error,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Create a savings goal
  Future<bool> createSavingsGoal({
    required String goalName,
    required double targetAmount,
    required DateTime targetDate,
    String? description,
  }) async {
    state = state.copyWith(status: WalletStatus.loading);
    try {
      logger.i('Creating savings goal: $goalName, target: $targetAmount, by: $targetDate');
      // TODO: Implement actual API call when backend endpoint is available
      // Example implementation:
      // final response = await _apiClient.post(
      //   '/wallet/savings-goals',
      //   data: {
      //     'goal_name': goalName,
      //     'target_amount': targetAmount,
      //     'target_date': targetDate.toIso8601String(),
      //     'description': description,
      //   },
      // );
      // return response['success'] == true;
      
      // For demo, simulate success
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(status: WalletStatus.loaded);
      return true;
    } catch (e) {
      logger.e('Create savings goal error: $e');
      state = state.copyWith(
        status: WalletStatus.error,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Wallet Provider
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final walletRepository = ref.watch(walletRepositoryProvider);
  return WalletNotifier(walletRepository);
});

/// Wallet balance provider
final walletBalanceProvider = Provider<double>((ref) {
  final walletState = ref.watch(walletProvider);
  return walletState.wallet?.balance ?? 0.0;
});

/// Total contributions provider
final totalContributionsProvider = Provider<double>((ref) {
  final walletState = ref.watch(walletProvider);
  return walletState.wallet?.totalContributions ?? 0.0;
});

/// Transactions provider
final transactionsProvider = Provider<List<Transaction>>((ref) {
  final walletState = ref.watch(walletProvider);
  return walletState.transactions;
});

/// Wallet error provider
final walletErrorProvider = Provider<String?>((ref) {
  final walletState = ref.watch(walletProvider);
  return walletState.error;
});
