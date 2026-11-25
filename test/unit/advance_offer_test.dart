import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/utils/advance_offer.dart';

/// The offer is priced by the backend and paid through an allocation list. If a
/// priced leg never reaches that list the member is undercharged, so these tests
/// pin the mapping rather than the rendering.
void main() {
  Map<String, dynamic> obligations(Map<String, dynamic> advance) => {
        'advance': advance,
      };

  test('carries every priced leg into the allocation', () {
    final offer = AdvanceOffer.fromObligations(obligations({
      'month': '2026-03',
      'savings': 5000,
      'administrative_fee': 1500,
      'loans': [
        {'loan_id': 'loan-uuid', 'amount': 2000},
      ],
      'fines': [
        {'id': 'fine-1', 'amount': 300},
      ],
      'total': 8800,
    }));

    expect(offer.toAllocations(), [
      {'type': 'savings', 'amount': 5000.0},
      {'type': 'fee', 'amount': 1500.0},
      {'type': 'loan_repayment', 'amount': 2000.0, 'loan_id': 'loan-uuid'},
      {'type': 'fine', 'amount': 300.0, 'fee_id': 'fine-1'},
    ]);
    expect(offer.total, 8800);
  });

  test('omits the fee leg for an exempt member so it is not taken twice', () {
    final offer = AdvanceOffer.fromObligations(obligations({
      'month': '2026-03',
      'savings': 5000,
      'administrative_fee': 0,
      'loans': const [],
      'fines': const [],
      'total': 5000,
    }));

    expect(offer.toAllocations(), [
      {'type': 'savings', 'amount': 5000.0},
    ]);
    expect(offer.caption, contains('deducted from salary'));
  });

  test('drops zero-value legs rather than sending them', () {
    final offer = AdvanceOffer.fromObligations(obligations({
      'month': '2026-03',
      'savings': 5000,
      'administrative_fee': 0,
      'loans': [
        {'loan_id': 'settled', 'amount': 0},
      ],
      'fines': [
        {'id': 'paid', 'amount': 0},
      ],
      'total': 5000,
    }));

    expect(offer.toAllocations(), [
      {'type': 'savings', 'amount': 5000.0},
    ]);
  });

  test('falls back to summing the legs when the backend omits a total', () {
    final offer = AdvanceOffer.fromObligations(obligations({
      'month': '2026-03',
      'savings': 5000,
      'administrative_fee': 1500,
      'loans': const [],
      'fines': const [],
    }));

    expect(offer.total, 6500);
    expect(offer.isPayable, isTrue);
  });

  test('is not payable without a month, so the card stays hidden', () {
    expect(AdvanceOffer.fromObligations(obligations(const {})).isPayable,
        isFalse);
    expect(
      AdvanceOffer.fromObligations(obligations({'month': '2026-03'})).isPayable,
      isFalse,
    );
  });

  test('labels a month key and passes an unknown key through unchanged', () {
    expect(formatMonthKey('2026-03'), 'March 2026');
    expect(formatMonthKey('2026-12'), 'December 2026');
    expect(formatMonthKey('garbage'), 'garbage');
    expect(formatMonthKey(''), '');
  });
}
