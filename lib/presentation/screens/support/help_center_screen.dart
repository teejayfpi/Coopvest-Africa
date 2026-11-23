import 'package:flutter/material.dart';

import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/content/help_faq.dart';
import 'ticket_creation_screen.dart';

/// Searchable help centre.
///
/// Answers the questions members ask most often without waiting for a person.
/// It sits in front of the ticket system rather than replacing it: whatever the
/// member cannot find ends in "Still need help?", which opens a ticket in the
/// matching category with the search terms already attached.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({Key? key}) : super(key: key);

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  HelpCategory? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEntry(HelpEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(CoopvestShape.headerRadius)),
      ),
      builder: (sheetContext) => _AnswerSheet(
        entry: entry,
        onStillNeedHelp: () {
          Navigator.of(sheetContext).pop();
          _openTicket(entry.category);
        },
      ),
    );
  }

  void _openTicket(HelpCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketCreationScreen(preselectedCategory: category.ticketCategory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.trim().isNotEmpty;
    final results = isSearching
        ? searchHelp(_query)
        : _selectedCategory == null
            ? const <HelpEntry>[]
            : helpByCategory(_selectedCategory!);

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Help Centre',
            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() {
                  _query = v;
                  _selectedCategory = null;
                }),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search, for example "withdrawal"',
                  prefixIcon: Icon(Icons.search, color: context.iconSecondary),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.clear, color: context.iconSecondary),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _selectedCategory = null;
                            });
                          },
                        ),
                  filled: true,
                  fillColor: context.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CoopvestShape.buttonRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: isSearching || _selectedCategory != null
                  ? _buildResults(results)
                  : _buildCategories(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(List<HelpEntry> results) {
    if (results.isEmpty) {
      return _buildNoResults();
    }
    final heading = _query.trim().isNotEmpty ? 'Answers' : _selectedCategory!.label;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      itemCount: results.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: CoopvestShape.gapSm),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: CoopvestShape.gapSm),
            child: Row(
              children: [
                Expanded(
                  child: Text(heading,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary)),
                ),
                if (_selectedCategory != null && _query.trim().isEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selectedCategory = null),
                    child: const Text('All topics'),
                  ),
              ],
            ),
          );
        }
        final entry = results[i - 1];
        return _HelpEntryTile(entry: entry, onTap: () => _openEntry(entry));
      },
    );
  }

  Widget _buildNoResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.search_off, size: 40, color: context.iconSecondary),
          const SizedBox(height: CoopvestShape.gapMd),
          Text(
            'No answer matched "$_query".',
            style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
          ),
          const SizedBox(height: CoopvestShape.gapXs),
          Text(
            'Our team can help with this. Send it to us and we will reply.',
            style: TextStyle(color: context.textSecondary),
          ),
          const SizedBox(height: CoopvestShape.gapLg),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _openTicket(HelpCategory.technical),
              icon: const Icon(Icons.report_problem, color: Colors.white),
              label: const Text('Contact Support',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: CoopvestColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoopvestShape.buttonRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text('Browse by topic',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
        const SizedBox(height: CoopvestShape.gapMd),
        for (final category in HelpCategory.values)
          Padding(
            padding: const EdgeInsets.only(bottom: CoopvestShape.gapSm),
            child: _CategoryTile(
              category: category,
              count: helpByCategory(category).length,
              onTap: () => setState(() => _selectedCategory = category),
            ),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.count, required this.onTap});

  final HelpCategory category;
  final int count;
  final VoidCallback onTap;

  static const Map<HelpCategory, IconData> _icons = {
    HelpCategory.contribution: Icons.savings_outlined,
    HelpCategory.loan: Icons.request_quote_outlined,
    HelpCategory.repayment: Icons.payments_outlined,
    HelpCategory.guarantor: Icons.handshake_outlined,
    HelpCategory.withdrawal: Icons.account_balance_wallet_outlined,
    HelpCategory.referral: Icons.card_giftcard_outlined,
    HelpCategory.kyc: Icons.verified_user_outlined,
    HelpCategory.technical: Icons.build_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CoopvestShape.cardRadius),
      child: Container(
        constraints: const BoxConstraints(minHeight: CoopvestShape.minTouchTarget),
        padding: const EdgeInsets.all(CoopvestShape.gapMd),
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(CoopvestShape.cardRadius),
          border: Border.all(color: context.dividerColor),
        ),
        child: Row(
          children: [
            Icon(_icons[category] ?? Icons.help_outline, color: CoopvestColors.primary),
            const SizedBox(width: CoopvestShape.gapMd),
            Expanded(
              child: Text(
                category.label,
                style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary),
              ),
            ),
            Text('$count', style: TextStyle(color: context.textSecondary, fontSize: 13)),
            const SizedBox(width: CoopvestShape.gapXs),
            Icon(Icons.chevron_right, color: context.iconSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _HelpEntryTile extends StatelessWidget {
  const _HelpEntryTile({required this.entry, required this.onTap});

  final HelpEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CoopvestShape.cardRadius),
      child: Container(
        constraints: const BoxConstraints(minHeight: CoopvestShape.minTouchTarget),
        padding: const EdgeInsets.all(CoopvestShape.gapMd),
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(CoopvestShape.cardRadius),
          border: Border.all(color: context.dividerColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.question,
                style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary),
              ),
            ),
            const SizedBox(width: CoopvestShape.gapSm),
            Icon(Icons.chevron_right, color: context.iconSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AnswerSheet extends StatelessWidget {
  const _AnswerSheet({required this.entry, required this.onStillNeedHelp});

  final HelpEntry entry;
  final VoidCallback onStillNeedHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: CoopvestShape.gapLg,
        right: CoopvestShape.gapLg,
        top: CoopvestShape.gapLg,
        bottom: CoopvestShape.gapLg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.question,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            const SizedBox(height: CoopvestShape.gapMd),
            Text(
              entry.answer,
              style: TextStyle(height: 1.45, color: context.textSecondary),
            ),
            const SizedBox(height: CoopvestShape.gapLg),
            SizedBox(
              width: double.infinity,
              height: CoopvestShape.minTouchTarget,
              child: OutlinedButton(
                onPressed: onStillNeedHelp,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CoopvestShape.buttonRadius),
                  ),
                ),
                child: const Text('Still need help? Contact support'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
