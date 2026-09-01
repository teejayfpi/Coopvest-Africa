import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/bank_directory.dart';

void main() {
  group('BankDirectory.bundled', () {
    final directory = BankDirectory.bundled();

    test('includes the requested digital/fintech banks', () {
      final names = directory.banks.map((b) => b.name).toList();
      for (final expected in [
        'OPay',
        'PalmPay',
        'Kuda Bank',
        'Moniepoint MFB',
        'FairMoney',
        'Rubies Bank',
        'VBank (VFD Microfinance Bank)',
      ]) {
        expect(names, contains(expected));
      }
    });

    test('assigns Paystack NUBAN codes to fintech banks', () {
      expect(directory.byName('OPay')!.code, '999992');
      expect(directory.byName('PalmPay')!.code, '999991');
      expect(directory.byName('Kuda Bank')!.code, '50211');
      expect(directory.byName('Moniepoint MFB')!.code, '50515');
      expect(directory.byName('FairMoney')!.code, '51318');
      expect(directory.byName('Rubies Bank')!.code, '125');
      expect(directory.byName('VBank (VFD Microfinance Bank)')!.code, '566');
    });

    test('keeps traditional commercial banks with their codes', () {
      expect(directory.byName('Access Bank')!.code, '044');
      expect(directory.byName('Zenith Bank')!.code, '057');
      expect(directory.byName('United Bank for Africa (UBA)')!.code, '033');
      expect(directory.byName('Guaranty Trust Bank')!.code, '058');
    });

    test('categorizes banks as commercial or digital', () {
      expect(directory.byName('Access Bank')!.category, 'commercial');
      expect(directory.byName('OPay')!.category, 'digital');
    });

    test('every bank has a non-empty name and code', () {
      for (final bank in directory.banks) {
        expect(bank.name, isNotEmpty);
        expect(bank.code, isNotEmpty);
      }
    });
  });

  group('BankDirectory.search', () {
    final directory = BankDirectory.bundled();

    test('finds banks by case-insensitive substring', () {
      final results = directory.search('opay');
      expect(results.length, 1);
      expect(results.first.name, 'OPay');
    });

    test('matches partial names', () {
      final results = directory.search('monie');
      expect(results.map((b) => b.name), contains('Moniepoint MFB'));
    });

    test('returns all banks for an empty query', () {
      expect(directory.search('').length, directory.banks.length);
      expect(directory.search('   ').length, directory.banks.length);
    });

    test('returns an empty list when nothing matches', () {
      expect(directory.search('nonexistent-bank-xyz'), isEmpty);
    });
  });

  group('BankDirectory.grouped', () {
    final directory = BankDirectory.bundled();

    test('puts commercial banks before digital banks', () {
      final groups = directory.grouped();
      final keys = groups.keys.toList();
      expect(keys.first, 'Commercial Banks');
      expect(keys, contains('Digital & Fintech Banks'));
    });

    test('sorts banks alphabetically within each group', () {
      final groups = directory.grouped();
      for (final group in groups.values) {
        final names = group.map((b) => b.name).toList();
        final sorted = [...names]..sort();
        expect(names, sorted);
      }
    });

    test('applies the search query before grouping', () {
      final groups = directory.grouped(query: 'kuda');
      final all = groups.values.expand((g) => g).toList();
      expect(all.length, 1);
      expect(all.first.name, 'Kuda Bank');
    });
  });

  group('BankDirectory.fromRemoteJson', () {
    test('parses the backend payload shape', () {
      final directory = BankDirectory.fromRemoteJson([
        {'name': 'OPay', 'code': '999992', 'category': 'digital'},
        {'name': 'Access Bank', 'code': '044', 'category': 'commercial'},
      ]);
      expect(directory.isRemote, isTrue);
      expect(directory.banks.length, 2);
      expect(directory.byName('OPay')!.category, 'digital');
    });

    test('drops entries with missing name or code', () {
      final directory = BankDirectory.fromRemoteJson([
        {'name': '', 'code': '044'},
        {'name': 'Access Bank', 'code': ''},
        {'name': 'Zenith Bank', 'code': '057'},
      ]);
      expect(directory.banks.length, 1);
      expect(directory.banks.first.name, 'Zenith Bank');
    });

    test('accepts the bundled label/code shape too', () {
      final directory = BankDirectory.fromRemoteJson([
        {'label': 'Kuda Bank', 'code': '50211', 'category': 'digital'},
      ]);
      expect(directory.banks.first.name, 'Kuda Bank');
    });
  });
}
