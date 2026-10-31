import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/services/registration_fee_status_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the durable "the server confirmed this fee is settled" record.
///
/// This store exists so a paying member can open the app offline without being
/// shown the payment screen. Its correctness matters in two directions:
///
///   1. A confirmation must survive to the next launch, or the offline bug
///      returns.
///   2. A confirmation must NOT leak between accounts on a shared device, or
///      one member's paid status would let another onto the dashboard.
///
/// Note what is *absent*: there is no `markUnsettled`. That is deliberate — an
/// "unpaid" is never cached, because a local unpaid could be used to clear the
/// gate by going offline. Only the server may conclude non-payment.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('settled confirmation survives a relaunch', () {
    test('an unmarked member reads as not confirmed, not as unpaid', () async {
      // A false here means "no confirmation on this device", which the gate
      // treats as unknown — never as "owes the fee".
      expect(
        await RegistrationFeeStatusStore.isSettledConfirmed('member-1'),
        isFalse,
      );
    });

    test('marking then reading returns true', () async {
      await RegistrationFeeStatusStore.markSettled('member-1');
      expect(
        await RegistrationFeeStatusStore.isSettledConfirmed('member-1'),
        isTrue,
      );
    });

    test('the confirmation is per member, not per device', () async {
      await RegistrationFeeStatusStore.markSettled('member-1');

      // A different member on the same device must not inherit it.
      expect(
        await RegistrationFeeStatusStore.isSettledConfirmed('member-2'),
        isFalse,
      );
      expect(
        await RegistrationFeeStatusStore.isSettledConfirmed('member-1'),
        isTrue,
      );
    });

    test('clearing removes only that member', () async {
      await RegistrationFeeStatusStore.markSettled('member-1');
      await RegistrationFeeStatusStore.markSettled('member-2');

      await RegistrationFeeStatusStore.clear('member-1');

      expect(
        await RegistrationFeeStatusStore.isSettledConfirmed('member-1'),
        isFalse,
      );
      expect(
        await RegistrationFeeStatusStore.isSettledConfirmed('member-2'),
        isTrue,
      );
    });
  });

  group('empty ids are ignored rather than keyed', () {
    test('marking and clearing an empty id is a no-op', () async {
      await RegistrationFeeStatusStore.markSettled('');
      await RegistrationFeeStatusStore.clear('');

      expect(await RegistrationFeeStatusStore.isSettledConfirmed(''), isFalse);
    });
  });
}
