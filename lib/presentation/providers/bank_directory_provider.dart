import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../data/models/bank_directory.dart';

/// Provides the supported-bank directory.
///
/// Fetches the list from the backend (`GET /api/v1/banks`) so it can be
/// updated without an app release; falls back to the bundled list when the
/// request fails.
final bankDirectoryProvider = FutureProvider<BankDirectory>((ref) async {
  try {
    final data = await ref.read(apiClientProvider).get('/banks');
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['banks'] is List &&
        (data['banks'] as List).isNotEmpty) {
      return BankDirectory.fromRemoteJson(data['banks'] as List);
    }
  } catch (_) {
    // Fall through to the bundled directory.
  }
  return BankDirectory.bundled();
});
