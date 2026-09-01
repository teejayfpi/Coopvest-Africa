import 'kyc_models.dart';

/// A single selectable bank in the bank directory.
class BankOption {
  final String name;
  final String code;

  /// 'commercial', 'digital', 'microfinance', or 'other'.
  final String category;

  const BankOption({
    required this.name,
    required this.code,
    this.category = 'commercial',
  });

  factory BankOption.fromJson(Map<String, dynamic> json) {
    return BankOption(
      name: (json['name'] ?? json['label'] ?? '') as String,
      code: (json['code'] ?? '') as String,
      category: (json['category'] ?? 'commercial') as String,
    );
  }
}

/// The ordered, grouped list of banks shown in pickers.
class BankDirectory {
  /// Banks fetched from the backend (or the bundled fallback), sorted
  /// alphabetically within the full list.
  final List<BankOption> banks;

  /// True when [banks] came from the remote directory rather than the
  /// bundled fallback list.
  final bool isRemote;

  const BankDirectory({required this.banks, this.isRemote = false});

  /// Bundled fallback directory compiled into the app.
  factory BankDirectory.bundled() {
    return BankDirectory(
      banks: BankTypes.banks.map(BankOption.fromJson).toList(),
    );
  }

  factory BankDirectory.fromRemoteJson(List<dynamic> json) {
    return BankDirectory(
      banks: json
          .whereType<Map<String, dynamic>>()
          .map(BankOption.fromJson)
          .where((b) => b.name.isNotEmpty && b.code.isNotEmpty)
          .toList(),
      isRemote: true,
    );
  }

  /// Case-insensitive substring search over bank names.
  List<BankOption> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return banks;
    return banks.where((b) => b.name.toLowerCase().contains(q)).toList();
  }

  /// Banks grouped for display: commercial first, then digital/fintech,
  /// then everything else — each group sorted alphabetically.
  Map<String, List<BankOption>> grouped({String query = ''}) {
    final results = search(query);
    int rank(BankOption b) {
      switch (b.category) {
        case 'commercial':
          return 0;
        case 'digital':
          return 1;
        default:
          return 2;
      }
    }

    final sorted = [...results]..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.name.compareTo(b.name);
      });

    final groups = <String, List<BankOption>>{};
    for (final b in sorted) {
      final label = switch (b.category) {
        'commercial' => 'Commercial Banks',
        'digital' => 'Digital & Fintech Banks',
        _ => 'Other Financial Institutions',
      };
      groups.putIfAbsent(label, () => []).add(b);
    }
    return groups;
  }

  BankOption? byName(String name) {
    for (final b in banks) {
      if (b.name == name) return b;
    }
    return null;
  }
}
