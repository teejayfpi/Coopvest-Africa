import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../data/models/fee_schedule.dart';

/// Provides the published fee schedule.
///
/// Fetches from the backend (`GET /api/v1/fees`) so the price list the app
/// shows is the price list the server levies, and can be corrected without an
/// app release. Falls back to the bundled schedule — built from the same
/// `AppConfig` constants the app charges from — when the request fails.
///
/// The fallback carries an empty hash on purpose, so a caller can tell a
/// server-confirmed revision from a bundled one.
final feeScheduleProvider = FutureProvider<FeeSchedule>((ref) async {
  try {
    final data = await ref.read(apiClientProvider).get('/v1/fees');
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['charges'] is List &&
        (data['charges'] as List).isNotEmpty) {
      return FeeSchedule.fromJson(data);
    }
  } catch (_) {
    // Fall through to the bundled schedule.
  }
  return FeeSchedule.bundled();
});
