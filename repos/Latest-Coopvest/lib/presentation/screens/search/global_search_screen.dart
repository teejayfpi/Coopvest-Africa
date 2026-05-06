import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';

/// Global search screen - searches across transactions, loans, and settings
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  
  // Search categories
  final List<SearchCategory> _categories = [
    SearchCategory(
      id: 'transactions',
      title: 'Transactions',
      icon: Icons.swap_horiz,
      items: [
        SearchItem(title: 'Contributions', subtitle: 'Monthly savings payments', route: '/contributions'),
        SearchItem(title: 'Withdrawals', subtitle: 'Savings withdrawal history', route: '/withdrawals'),
        SearchItem(title: 'Loan Repayments', subtitle: 'Loan payment history', route: '/loan-repayments'),
        SearchItem(title: 'Bank Transfer', subtitle: 'Transfer to bank account', route: '/transfer'),
        SearchItem(title: 'Airtime & Bills', subtitle: 'Buy airtime and pay bills', route: '/bills'),
      ],
    ),
    SearchCategory(
      id: 'loans',
      title: 'Loans',
      icon: Icons.handshake,
      items: [
        SearchItem(title: 'Apply for Loan', subtitle: 'Request a new loan', route: '/loan-application'),
        SearchItem(title: 'My Loans', subtitle: 'View active loans', route: '/loan-dashboard'),
        SearchItem(title: 'Loan Calculator', subtitle: 'Calculate monthly payments', route: '/loan-calculator'),
        SearchItem(title: 'Guarantors', subtitle: 'Manage guarantor requests', route: '/guarantors'),
      ],
    ),
    SearchCategory(
      id: 'savings',
      title: 'Savings',
      icon: Icons.savings,
      items: [
        SearchItem(title: 'Savings Goals', subtitle: 'Set and track savings targets', route: '/savings-goal'),
        SearchItem(title: 'Total Savings', subtitle: 'View your total balance', route: '/wallet'),
        SearchItem(title: 'Auto-Save', subtitle: 'Set up automatic savings', route: '/auto-save'),
        SearchItem(title: 'Interest Earned', subtitle: 'View interest earnings', route: '/interest'),
      ],
    ),
    SearchCategory(
      id: 'settings',
      title: 'Settings',
      icon: Icons.settings,
      items: [
        SearchItem(title: 'Profile', subtitle: 'Edit personal information', route: '/profile'),
        SearchItem(title: 'Security', subtitle: 'Password, PIN, biometrics', route: '/security'),
        SearchItem(title: 'Notifications', subtitle: 'Push notification preferences', route: '/notifications'),
        SearchItem(title: 'Bank Accounts', subtitle: 'Manage linked banks', route: '/bank-accounts'),
        SearchItem(title: 'KYC Verification', subtitle: 'Upload identification documents', route: '/kyc-employment-details'),
        SearchItem(title: 'Referrals', subtitle: 'Invite friends and earn rewards', route: '/referrals'),
      ],
    ),
    SearchCategory(
      id: 'support',
      title: 'Support',
      icon: Icons.help,
      items: [
        SearchItem(title: 'Help Center', subtitle: 'FAQs and user guides', route: '/support'),
        SearchItem(title: 'Live Chat', subtitle: 'Talk to support team', route: '/live-chat'),
        SearchItem(title: 'Submit Ticket', subtitle: 'Create a support ticket', route: '/create-ticket'),
        SearchItem(title: 'Contact Us', subtitle: 'Email and phone support', route: '/contact'),
      ],
    ),
  ];

  List<SearchItem> get _filteredItems {
    if (_query.isEmpty) return [];
    
    List<SearchItem> results = [];
    for (var category in _categories) {
      for (var item in category.items) {
        if (item.title.toLowerCase().contains(_query.toLowerCase()) ||
            item.subtitle.toLowerCase().contains(_query.toLowerCase())) {
          results.add(item);
        }
      }
    }
    return results;
  }

  List<SearchCategory> get _filteredCategories {
    if (_query.isNotEmpty) return [];
    return _categories;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search transactions, loans, settings...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: context.textSecondary),
          ),
          style: TextStyle(color: context.textPrimary),
          onChanged: (value) {
            setState(() {
              _query = value;
            });
          },
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                });
              },
            ),
        ],
      ),
      body: _query.isEmpty 
          ? _buildBrowseCategories() 
          : _buildSearchResults(),
    );
  }

  Widget _buildBrowseCategories() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        final category = _filteredCategories[index];
        return _buildCategorySection(category);
      },
    );
  }

  Widget _buildCategorySection(SearchCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(category.icon, color: CoopvestColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              category.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...category.items.map((item) => _buildSearchItem(item)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSearchResults() {
    final results = _filteredItems;
    
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: context.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching for something else',
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return _buildSearchItem(results[index], showCategory: true);
      },
    );
  }

  Widget _buildSearchItem(SearchItem item, {bool showCategory = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: CoopvestColors.primary.withOpacity(0.1),
          child: Icon(Icons.search, color: CoopvestColors.primary, size: 20),
        ),
        title: Text(
          item.title,
          style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary),
        ),
        subtitle: Text(
          item.subtitle,
          style: TextStyle(color: context.textSecondary, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: context.textSecondary),
        onTap: () {
          // Navigate to the item's route
          Navigator.pop(context);
          if (item.route.isNotEmpty) {
            Navigator.pushNamed(context, item.route);
          }
        },
      ),
    );
  }
}

class SearchCategory {
  final String id;
  final String title;
  final IconData icon;
  final List<SearchItem> items;

  SearchCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.items,
  });
}

class SearchItem {
  final String title;
  final String subtitle;
  final String route;

  SearchItem({
    required this.title,
    required this.subtitle,
    required this.route,
  });
}
