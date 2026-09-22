import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/announcement_models.dart';
import '../../providers/announcement_provider.dart';

/// Shows admin announcements flagged as a popup, once each.
///
/// Behaviour that matters:
///   * An announcement pops up **once per member**, not on every launch. The
///     id is recorded locally after being shown, and also marked read
///     server-side, so a member on a second device is not shown it again.
///   * `dismissible: false` (a critical notice) has no close button and cannot
///     be dismissed by tapping outside.
///   * Popups are queued and shown one at a time, oldest first, so two
///     announcements do not fight over the same dialog.
///
/// Call `AnnouncementPopupHost.checkAndShow(context, ref)` after the home
/// screen has loaded announcements.
class AnnouncementPopupHost {
  static const _prefix = 'announcement_shown_';
  static bool _isShowing = false;

  /// Show any unseen popup announcements. Safe to call repeatedly.
  static Future<void> checkAndShow(BuildContext context, WidgetRef ref) async {
    if (_isShowing || !context.mounted) return;

    final state = ref.read(announcementProvider);
    final popups = state.announcements
        .where((a) => a.showAsPopup && !a.isExpired)
        .toList();
    if (popups.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    // Oldest first, so a backlog is consumed in the order it was sent.
    popups.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final unseen = <Announcement>[];
    for (final a in popups) {
      // Server-side read state is authoritative; the local flag is a fast path
      // that avoids a flicker before the network answers.
      final shownLocally = prefs.getBool('$_prefix${a.id}') ?? false;
      if (!a.isRead && !shownLocally) unseen.add(a);
    }
    if (unseen.isEmpty) return;

    _isShowing = true;
    try {
      for (final announcement in unseen) {
        if (!context.mounted) break;

        await _showOne(context, announcement);

        // Record it as shown before moving on, so a crash mid-queue cannot
        // cause a repeat on next launch.
        await prefs.setBool('$_prefix${announcement.id}', true);
        try {
          await ref.read(announcementProvider.notifier).markAsRead(announcement.id);
        } catch (_) {
          // A failed mark-read must not block the remaining popups; the local
          // flag already prevents a repeat on this device.
        }
      }
    } finally {
      _isShowing = false;
    }
  }

  static Future<void> _showOne(BuildContext context, Announcement a) {
    final isCritical = a.priority == 'critical';
    return showDialog<void>(
      context: context,
      // A critical, non-dismissible notice must be acknowledged with the button.
      barrierDismissible: a.dismissible && !isCritical,
      builder: (ctx) => PopScope(
        canPop: a.dismissible && !isCritical,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isCritical ? Icons.warning_amber_rounded : Icons.campaign_rounded,
                color: isCritical ? Colors.orange.shade700 : Theme.of(ctx).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.title.isEmpty ? 'Announcement' : a.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              a.content,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ),
          actions: [
            if (a.dismissible && !isCritical)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            if (a.actionUrl != null && a.actionUrl!.isNotEmpty)
              FilledButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final uri = Uri.tryParse(a.actionUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(a.actionLabel?.isNotEmpty == true ? a.actionLabel! : 'Open'),
              )
            else if (!a.dismissible || isCritical)
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
          ],
        ),
      ),
    );
  }

  /// Clear the local "already shown" flags. Used on logout so a member who
  /// signs back in sees current announcements again where appropriate.
  static Future<void> resetShownFlags() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
