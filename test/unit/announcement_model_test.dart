import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/announcement_models.dart';

/// The announcement model decides two things that are visible to members: which
/// display surface an announcement appears on, and whether its text renders at
/// all. Both were broken before this work — the model read `content`/`type`
/// while the API returned `body`/`category`, so a real announcement rendered
/// blank.
void main() {
  group('Announcement display surfaces', () {
    Announcement make(String displayMode) => Announcement(
          id: 'a1',
          title: 'T',
          content: 'C',
          type: 'info',
          createdAt: DateTime.now(),
          displayMode: displayMode,
        );

    test('marquee appears only in the ticker', () {
      final a = make('marquee');
      expect(a.showInMarquee, isTrue);
      expect(a.showAsBanner, isFalse);
      expect(a.showAsPopup, isFalse);
    });

    test('banner appears only in the list', () {
      final a = make('banner');
      expect(a.showInMarquee, isFalse);
      expect(a.showAsBanner, isTrue);
      expect(a.showAsPopup, isFalse);
    });

    test('popup appears only as a dialog', () {
      final a = make('popup');
      expect(a.showInMarquee, isFalse);
      expect(a.showAsBanner, isFalse);
      expect(a.showAsPopup, isTrue);
    });

    test('"all" appears on every surface', () {
      final a = make('all');
      expect(a.showInMarquee, isTrue);
      expect(a.showAsBanner, isTrue);
      expect(a.showAsPopup, isTrue);
    });

    test('an unknown mode falls back to banner, not to nothing', () {
      // A future server value must not make an announcement vanish.
      final a = make('carousel');
      expect(a.showAsBanner, isTrue);
    });
  });

  group('Announcement parsing tolerates both contracts', () {
    test('reads the camelCase shape the API returns', () {
      final a = Announcement.fromJson({
        'id': 'x1',
        'title': 'Contribution received',
        'content': 'We got your money',
        'type': 'success',
        'createdAt': '2026-09-01T10:00:00Z',
        'displayMode': 'popup',
        'isPinned': true,
        'dismissible': false,
      });
      expect(a.title, 'Contribution received');
      expect(a.content, 'We got your money');
      expect(a.type, 'success');
      expect(a.displayMode, 'popup');
      expect(a.isPinned, isTrue);
      expect(a.dismissible, isFalse);
      expect(a.createdAt.year, 2026);
    });

    test('also reads the raw snake_case table shape', () {
      // This is the shape that previously produced a BLANK announcement when
      // the API returned the table row unchanged.
      final a = Announcement.fromJson({
        'id': 'x2',
        'title': 'From the table',
        'body': 'Body text',
        'category': 'warning',
        'created_at': '2026-08-15T09:00:00Z',
        'display_mode': 'marquee',
        'is_pinned': true,
      });
      expect(a.content, 'Body text');
      expect(a.type, 'warning');
      expect(a.displayMode, 'marquee');
      expect(a.isPinned, isTrue);
    });

    test('a missing display mode defaults to banner', () {
      final a = Announcement.fromJson({'id': 'x3', 'title': 'T', 'body': 'B'});
      expect(a.displayMode, 'banner');
    });

    test('a missing date does not throw', () {
      final a = Announcement.fromJson({'id': 'x4', 'title': 'T', 'body': 'B'});
      expect(a.createdAt, isNotNull);
    });

    test('a malformed date does not throw', () {
      final a = Announcement.fromJson({
        'id': 'x5', 'title': 'T', 'body': 'B', 'createdAt': 'not-a-date',
      });
      expect(a.createdAt, isNotNull);
    });

    test('content falls back across all three spellings', () {
      expect(Announcement.fromJson({'id': 'a', 'content': 'one'}).content, 'one');
      expect(Announcement.fromJson({'id': 'b', 'body': 'two'}).content, 'two');
      expect(Announcement.fromJson({'id': 'c', 'message': 'three'}).content, 'three');
    });
  });

  group('Expiry', () {
    test('an announcement with no expiry never expires', () {
      final a = Announcement(
        id: 'a', title: 'T', content: 'C', type: 'info', createdAt: DateTime.now(),
      );
      expect(a.isExpired, isFalse);
    });

    test('a past expiry is expired', () {
      final a = Announcement(
        id: 'a', title: 'T', content: 'C', type: 'info',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(a.isExpired, isTrue);
    });

    test('a future expiry is not expired', () {
      final a = Announcement(
        id: 'a', title: 'T', content: 'C', type: 'info', createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      expect(a.isExpired, isFalse);
    });
  });
}
