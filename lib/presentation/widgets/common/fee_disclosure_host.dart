import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme_extension.dart';
import '../../../core/services/fee_disclosure_store.dart';
import '../../../data/models/fee_schedule.dart';
import '../../providers/fee_schedule_provider.dart';
import 'fee_disclosure_sheet.dart';

/// Shows the published fee schedule once, at first open.
///
/// Call [maybeShow] once the first screen is on stage. It is safe to call on
/// every launch: it decides from the schedule hash whether there is anything
/// the member has not yet been shown.
///
/// What it deliberately does NOT do:
///   * It does not block the app. The sheet is dismissible and the caller
///     continues regardless of the outcome.
///   * It does not record acceptance. That belongs to registration, where the
///     member is identifiable.
///   * It does not show the bundled schedule as if it were the published one.
///     If the fetch failed, the sheet still appears (better than nothing) but
///     is not recorded as seen, so the real schedule is shown when it arrives.
class FeeDisclosureHost {
  static bool _isShowing = false;

  /// Show the fee disclosure if this device has not seen this revision.
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    if (_isShowing || !context.mounted) return;

    FeeSchedule schedule;
    try {
      schedule = await ref.read(feeScheduleProvider.future);
    } catch (_) {
      // The provider already falls back to the bundled schedule, so this is
      // only reached on an unexpected failure. Do not block the screen.
      return;
    }
    if (!context.mounted) return;

    final needs = await FeeDisclosureStore.needsShowing(schedule.hash);
    if (!needs || !context.mounted) return;

    _isShowing = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        backgroundColor: context.cardBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => FeeDisclosureSheet(schedule: schedule, onDismissed: () {}),
      );

      // Record only a server-confirmed revision. A bundled schedule (empty
      // hash) is shown but not recorded, so the live schedule supersedes it
      // rather than being suppressed by it.
      if (schedule.hash.isNotEmpty) {
        await FeeDisclosureStore.markShown(schedule.hash);
      }
    } catch (_) {
      // A failure to present the sheet must never break the screen it is on.
    } finally {
      _isShowing = false;
    }
  }
}
