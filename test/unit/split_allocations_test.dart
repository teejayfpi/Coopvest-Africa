import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/utils/split_allocations.dart';

/// A split payment rebuilds allocations from four amount fields, which loses
/// the identity of the rows those amounts came from. Without an id the backend
/// settles the oldest outstanding row of that type, which may not be the one the
/// member was shown. Collapsing two rows of the same type is worse still: one
/// allocation settles only the first and marks it paid for the whole sum.
void main() {
  List<Map<String, dynamic>> amounts(List<Map<String, dynamic>> allocations) =>
      allocations.map((a) => {'type': a['type'], 'amount': a['amount']}).toList();

  test('two fines of the same type are sent as two allocations', () {
    final allocations = allocateFeeAmount('fine', 3500, const [
      KnownFeeRow(id: 'fine-1', amount: 3000),
      KnownFeeRow(id: 'fine-2', amount: 500),
    ]);

    expect(allocations, [
      {'type': 'fine', 'amount': 3000.0, 'fee_id': 'fine-1'},
      {'type': 'fine', 'amount': 500.0, 'fee_id': 'fine-2'},
    ]);
  });

  test('each allocation carries the id of the row it settles', () {
    final allocations = allocateFeeAmount('fee', 2000, const [
      KnownFeeRow(id: 'fee-1', amount: 1500),
      KnownFeeRow(id: 'fee-2', amount: 500),
    ]);

    expect(allocations.map((a) => a['fee_id']), ['fee-1', 'fee-2']);
  });

  test('an amount below the first row covers only that row', () {
    // A member who typed less than the first fine is charged for that fine
    // only, not for a row they did not include.
    final allocations = allocateFeeAmount('fine', 1000, const [
      KnownFeeRow(id: 'fine-1', amount: 3000),
      KnownFeeRow(id: 'fine-2', amount: 500),
    ]);

    expect(allocations, [
      {'type': 'fine', 'amount': 1000.0, 'fee_id': 'fine-1'},
    ]);
  });

  test('an amount beyond the known rows leaves an unlinked remainder', () {
    // No id on the remainder, so the backend applies it to the oldest
    // outstanding row of that type rather than inventing one.
    final allocations = allocateFeeAmount('fine', 4000, const [
      KnownFeeRow(id: 'fine-1', amount: 3000),
    ]);

    expect(allocations, [
      {'type': 'fine', 'amount': 3000.0, 'fee_id': 'fine-1'},
      {'type': 'fine', 'amount': 1000.0},
    ]);
  });

  test('no known rows sends the whole amount unlinked', () {
    final allocations = allocateFeeAmount('fee', 1500, const []);

    expect(allocations, [
      {'type': 'fee', 'amount': 1500.0},
    ]);
  });

  test('a zero amount allocates nothing', () {
    expect(allocateFeeAmount('fine', 0, const [
      KnownFeeRow(id: 'fine-1', amount: 3000),
    ]), isEmpty);
  });

  test('the allocated total always equals the amount typed', () {
    const rows = [
      KnownFeeRow(id: 'fine-1', amount: 3000),
      KnownFeeRow(id: 'fine-2', amount: 500),
    ];
    for (final typed in [0.0, 500.0, 3000.0, 3500.0, 9000.0]) {
      final total = allocateFeeAmount('fine', typed, rows)
          .fold<double>(0, (s, a) => s + (a['amount'] as double));
      expect(total, typed, reason: 'typed $typed must be fully allocated');
    }
  });

  test('an empty id is omitted rather than sent as null', () {
    final allocations = allocateFeeAmount('fine', 100, const [
      KnownFeeRow(id: '', amount: 100),
    ]);

    expect(allocations.single.containsKey('fee_id'), isFalse);
    expect(amounts(allocations).single['amount'], 100.0);
  });
}
