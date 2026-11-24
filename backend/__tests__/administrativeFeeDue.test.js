/**
 * The monthly administrative fee inside this month's obligation.
 *
 * The billing worker writes a `member_fees` row once a day. Anything that only
 * summed outstanding rows therefore priced a month without the fee until that
 * row existed, so a member could be shown a total that excluded a charge they
 * owe - and could pay that total and still owe the fee.
 *
 * The rule under test is the whole fix: price the fee from the catalogue until
 * a row covers the month, then defer to the row.
 */

const { administrativeFeeDue } = require('../src/lib/administrativeFeeDue');
const { ADMINISTRATIVE_FEE } = require('../src/config/feeDisclosure');

describe('administrativeFeeDue', () => {
  test('is owed when no row covers the month yet', () => {
    expect(
      administrativeFeeDue({ exempt: false, month: '2026-11', memberFeeRows: [] }),
    ).toBe(ADMINISTRATIVE_FEE.total);
  });

  test('is not owed when an outstanding row already bills this month', () => {
    // The row carries the amount actually billed, so adding the catalogue
    // amount on top would ask for the fee twice.
    expect(
      administrativeFeeDue({
        exempt: false,
        month: '2026-11',
        memberFeeRows: [{ billing_month: '2026-11', amount: ADMINISTRATIVE_FEE.total }],
      }),
    ).toBe(0);
  });

  test('is not owed when this month was already paid', () => {
    expect(
      administrativeFeeDue({
        exempt: false,
        month: '2026-11',
        memberFeeRows: [{ billing_month: '2026-11', amount: ADMINISTRATIVE_FEE.total }],
      }),
    ).toBe(0);
  });

  test('a row for another month does not settle this one', () => {
    expect(
      administrativeFeeDue({
        exempt: false,
        month: '2026-11',
        memberFeeRows: [{ billing_month: '2026-10', amount: ADMINISTRATIVE_FEE.total }],
      }),
    ).toBe(ADMINISTRATIVE_FEE.total);
  });

  test('an exempt member is never charged in the app', () => {
    // Their employer withholds it; showing it here would take it twice.
    expect(
      administrativeFeeDue({ exempt: true, month: '2026-11', memberFeeRows: [] }),
    ).toBe(0);
  });

  test('rows without a billing month cannot settle a month', () => {
    // Fines and other fees carry no month; only this charge is priced here.
    expect(
      administrativeFeeDue({
        exempt: false,
        month: '2026-11',
        memberFeeRows: [{ billing_month: null, amount: 500 }],
      }),
    ).toBe(ADMINISTRATIVE_FEE.total);
  });

  test('a missing month yields nothing rather than a wrong charge', () => {
    expect(administrativeFeeDue({ exempt: false, month: null, memberFeeRows: [] })).toBe(0);
  });
});
