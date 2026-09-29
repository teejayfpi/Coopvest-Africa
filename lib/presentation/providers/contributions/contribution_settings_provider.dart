import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// The member's contribution preferences: how they contribute, the amount they
/// pledged, and the day of the month they pay.
class ContributionSettings {
  final String method;
  final double? monthlyAmount;
  final int? preferredDay;

  const ContributionSettings({
    this.method = 'manual',
    this.monthlyAmount,
    this.preferredDay,
  });
}

/// Reads `GET /user/contribution-method`.
///
/// The reminder logic used to hardcode the 5th and ₦5,000, so a member who
/// chose a different day or amount got nudged on the wrong date for the wrong
/// figure. Sourced from the server because that is where the settings screen
/// writes them.
final contributionSettingsProvider =
    FutureProvider<ContributionSettings>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final data = await apiClient.get('/user/contribution-method');
  final method = (data is Map && data['contributionMethod'] is Map)
      ? data['contributionMethod'] as Map
      : const {};
  return ContributionSettings(
    method: method['method'] as String? ?? 'manual',
    monthlyAmount: (method['monthlyAmount'] as num?)?.toDouble(),
    preferredDay: (method['preferredDay'] as num?)?.toInt(),
  );
});
