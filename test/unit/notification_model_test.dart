import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/notification_models.dart';

void main() {
  group('AppNotification.fromJson', () {
    test('reads the text from the backend `message` column', () {
      // The backend serialises the row's `message` into `body`, but the
      // realtime (Supabase) path receives the raw row, which only has
      // `message`. Regression guard for empty realtime pop-ups.
      final n = AppNotification.fromJson({
        'id': 42,
        'profile_id': 'user-1',
        'title': 'Deposit received',
        'message': 'Your deposit of NGN 5,000 was credited.',
        'type': 'wallet_credited',
        'created_at': '2024-03-01T09:00:00.000Z',
        'is_read': false,
      });

      expect(n.id, '42');
      expect(n.userId, 'user-1');
      expect(n.title, 'Deposit received');
      expect(n.body, 'Your deposit of NGN 5,000 was credited.');
      expect(n.type, 'wallet_credited');
      expect(n.isRead, isFalse);
      expect(n.timestamp.toUtc(), DateTime.utc(2024, 3, 1, 9));
    });

    test('prefers the serialised `body` when present', () {
      final n = AppNotification.fromJson({
        'id': 'x',
        'body': 'serialised body',
        'message': 'raw message',
      });
      expect(n.body, 'serialised body');
    });

    test('tolerates a missing timestamp', () {
      final n = AppNotification.fromJson({'id': 'x'});
      expect(n.timestamp, isA<DateTime>());
      expect(n.icon, 'notifications');
      expect(n.type, 'system');
    });
  });
}
