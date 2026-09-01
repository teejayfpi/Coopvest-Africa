import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/bank_directory.dart';
import '../../providers/bank_directory_provider.dart';

/// A bank-selection field with search.
///
/// Tapping the field opens a bottom sheet listing every supported bank —
/// commercial banks first, then digital/fintech institutions — with a
/// search box for filtering. The list comes from the backend bank directory
/// when reachable, otherwise from the bundled fallback list.
class BankSelectorField extends ConsumerWidget {
  final String label;
  final String hint;

  /// Currently selected bank, or null.
  final BankOption? value;

  final ValueChanged<BankOption> onChanged;

  const BankSelectorField({
    Key? key,
    this.label = 'Select Bank *',
    this.hint = 'Select your bank',
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directoryAsync = ref.watch(bankDirectoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            BankDirectory directory;
            final cached = directoryAsync.valueOrNull;
            if (cached != null) {
              directory = cached;
            } else {
              try {
                directory = await ref.read(bankDirectoryProvider.future);
              } catch (_) {
                directory = BankDirectory.bundled();
              }
            }
            if (!context.mounted) return;
            final selected = await showModalBottomSheet<BankOption>(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => _BankSearchSheet(directory: directory),
            );
            if (selected != null) onChanged(selected);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.cardBackground,
              border: Border.all(color: context.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value?.name ?? hint,
                    style: TextStyle(
                      color: value != null
                          ? context.textPrimary
                          : context.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: context.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BankSearchSheet extends StatefulWidget {
  final BankDirectory directory;

  const _BankSearchSheet({required this.directory});

  @override
  State<_BankSearchSheet> createState() => _BankSearchSheetState();
}

class _BankSearchSheetState extends State<_BankSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.directory.grouped(query: _query);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search banks…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        'No banks match "$_query"',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: CoopvestColors.primary,
                              ),
                            ),
                          ),
                          for (final bank in entry.value)
                            ListTile(
                              dense: true,
                              title: Text(bank.name),
                              onTap: () =>
                                  Navigator.of(context).pop(bank),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}
