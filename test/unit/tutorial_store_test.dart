import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/services/tutorial_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the "this member has seen the tutorial" flag.
///
/// The flag drives whether a walkthrough covers the dashboard on launch, so the
/// failure modes matter in both directions:
///
///   1. If it is not sticky, the tutorial reappears every launch and members
///      learn to dismiss it without reading — the exact opposite of training.
///   2. If it leaks between members, a second person on a shared phone never
///      gets introduced to the app at all.
///
/// Note that a read failure deliberately resolves to `false` (show it). Being
/// shown the tutorial twice is recoverable; never being shown it is not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('completion survives a relaunch', () {
    test('a fresh member reads as not seen', () async {
      expect(await TutorialStore.hasSeen('member-1'), isFalse);
    });

    test('marking then reading returns true', () async {
      await TutorialStore.markSeen('member-1');
      expect(await TutorialStore.hasSeen('member-1'), isTrue);
    });

    test('reading is stable across repeated calls', () async {
      await TutorialStore.markSeen('member-1');
      expect(await TutorialStore.hasSeen('member-1'), isTrue);
      expect(await TutorialStore.hasSeen('member-1'), isTrue);
    });
  });

  group('the flag is per member, not per device', () {
    test('one member seeing it does not mark another', () async {
      await TutorialStore.markSeen('member-1');

      expect(await TutorialStore.hasSeen('member-1'), isTrue);
      expect(await TutorialStore.hasSeen('member-2'), isFalse);
    });

    test('clearing removes only that member', () async {
      await TutorialStore.markSeen('member-1');
      await TutorialStore.markSeen('member-2');

      await TutorialStore.clear('member-1');

      expect(await TutorialStore.hasSeen('member-1'), isFalse);
      expect(await TutorialStore.hasSeen('member-2'), isTrue);
    });
  });

  group('empty ids are ignored rather than keyed', () {
    // An empty id would otherwise write a shared key that every signed-out
    // state reads, which is how one device's flag would apply to everyone.
    test('marking an empty id writes nothing', () async {
      await TutorialStore.markSeen('');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('tutorial_seen:')),
          isEmpty);
    });

    test('reading and clearing an empty id are no-ops', () async {
      expect(await TutorialStore.hasSeen(''), isFalse);
      await TutorialStore.clear('');
      expect(await TutorialStore.hasSeen(''), isFalse);
    });
  });

  group('replaying', () {
    test('clear then mark leaves the member as having seen it again', () async {
      await TutorialStore.markSeen('member-1');
      await TutorialStore.clear('member-1');
      expect(await TutorialStore.hasSeen('member-1'), isFalse);

      await TutorialStore.markSeen('member-1');
      expect(await TutorialStore.hasSeen('member-1'), isTrue);
    });
  });
}
