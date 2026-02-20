import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../data/models/contributions/monthly_contribution.dart';
import '../../../presentation/providers/contributions/contribution_provider.dart';
import 'contribution_detail_screen.dart';

/// Monthly Contributions Screen
/// Provides comprehensive view of member contributions
class MonthlyContributionsScreen extends ConsumerStatefulWidget {
  const MonthlyContributionsScreen({super.key});

  @override
  ConsumerState<MonthlyContributionsScreen> createState() =>
      _MonthlyContributionsScreenState();
}

class _MonthlyContributionsScreenState
    extends ConsumerState<MonthlyContributionsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(contributionProvider.notifier);
      if (ref.read(contributionProvider).hasMore) {
        notifier.loadMoreContributions();
      }
    }
  }

  Future<void> _loadData() async {
    await ref.read(contributionProvider.notifier).loadContributions();
  }

  Future<void> _refresh() async {
    await ref.read(contributionProvider.notifier).refreshContributions();
  }

  void _onContributionTap(MonthlyContribution contribution) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ContributionDetailScreen(contributionId: contribution.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contributionProvider);
    final summary = state.summary;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: CoopvestColors.primary,
        child: Column(
          children: [
            // Summary Cards Section
            if (summary != null) _buildSummarySection(context, summary),
            
            // Filter Controls
            _buildFilterControls(context, state.filter),

            // Expanded List Section
            Expanded(
              child: _buildBody(state),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: CoopvestColors.primary,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Contributions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _getCurrentMonthYear(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  String _getCurrentMonthYear() {
    final now = DateTime.now();
    return DateFormat('MMMM yyyy').format(now);
  }

  Widget _buildSummarySection(BuildContext context, ContributionSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CoopvestColors.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Status Badge
          _buildStatusBadge(context, summary.contributionStatus),
          const SizedBox(height: 16),
          
          // Main Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context,
                  'This Month',
                  summary.totalThisMonth.formatNumber(),
                  Icons.calendar_today,
                  CoopvestColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  'This Year',
                  summary.totalThisYear.formatNumber(),
                  Icons.date_range,
                  CoopvestColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context,
                  'Lifetime',
                  summary.lifetimeContributions.formatNumber(),
                  Icons.account_balance,
                  CoopvestColors.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  'Expected',
                  summary.expectedMonthlyAmount.formatNumber(),
                  Icons.trending_up,
                  CoopvestColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color badgeColor;
    String statusText;

    switch (status) {
      case 'up_to_date':
        badgeColor = CoopvestColors.success;
        statusText = 'Up to Date';
        break;
      case 'overdue':
        badgeColor = CoopvestColors.error;
        statusText = 'Overdue';
        break;
      case 'pending':
        badgeColor = CoopvestColors.warning;
        statusText = 'Pending';
        break;
      default:
        badgeColor = CoopvestColors.info;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'N$value',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: CoopvestColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterControls(BuildContext context, ContributionFilter filter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contributions...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(contributionProvider.notifier)
                            .applyFilter(filter.copyWith(searchQuery: ''));
                      },
                    )
                  : null,
              filled: true,
              fillColor: context.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              // Debounce search
              Future.delayed(const Duration(milliseconds: 500), () {
                ref
                    .read(contributionProvider.notifier)
                    .applyFilter(filter.copyWith(searchQuery: value));
              });
            },
          ),
          const SizedBox(height: 12),
          
          // Quick Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, 'This Month', filter.thisMonth(),
                    _isActiveFilter(filter, 'this_month')),
                const SizedBox(width: 8),
                _buildFilterChip(context, 'Last 3 Months', filter.last3Months(),
                    _isActiveFilter(filter, '3_months')),
                const SizedBox(width: 8),
                _buildFilterChip(context, 'Last 6 Months', filter.last6Months(),
                    _isActiveFilter(filter, '6_months')),
                const SizedBox(width: 8),
                _buildFilterChip(context, 'This Year', filter.thisYear(),
                    _isActiveFilter(filter, 'this_year')),
                const SizedBox(width: 8),
                _buildFilterChip(context, 'All Time', filter.allTime(),
                    _isActiveFilter(filter, 'all_time')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isActiveFilter(ContributionFilter filter, String filterType) {
    final now = DateTime.now();
    switch (filterType) {
      case 'this_month':
        return filter.year == now.year &&
            filter.month == now.month;
      case '3_months':
        return filter.startDate != null &&
            filter.startDate!.isAfter(DateTime(now.year, now.month - 3));
      case '6_months':
        return filter.startDate != null &&
            filter.startDate!.isAfter(DateTime(now.year, now.month - 6));
      case 'this_year':
        return filter.year == now.year;
      case 'all_time':
        return filter.year == null && filter.month == null;
      default:
        return false;
    }
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    ContributionFilter filterFn,
    bool isActive,
  ) {
    return FilterChip(
      label: Text(label),
      selected: isActive,
      selectedColor: CoopvestColors.primary.withOpacity(0.1),
      checkmarkColor: CoopvestColors.primary,
      labelStyle: TextStyle(
        color: isActive ? CoopvestColors.primary : context.textSecondary,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (selected) async {
        if (selected) {
          await ref.read(contributionProvider.notifier).applyFilter(filterFn());
        }
      },
    );
  }

  Widget _buildBody(ContributionState state) {
    if (state.isLoading && state.contributions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == ContributionStatus.error &&
        state.contributions.isEmpty) {
      return _buildErrorState(state.error);
    }

    if (state.contributions.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.contributions.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.contributions.length) {
          return const Center(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        final contribution = state.contributions[index];
        return _buildContributionCard(context, contribution);
      },
    );
  }

  Widget _buildContributionCard(
    BuildContext context,
    MonthlyContribution contribution,
  ) {
    final monthYear = _parseMonthYear(contribution.contributionMonth);
    final statusColor = _getStatusColor(contribution.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _onContributionTap(contribution),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Month and Year
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthYear['month'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        monthYear['year'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      contribution.status.displayName,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: context.dividerColor.withOpacity(0.5)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondary,
                        ),
                      ),
                      Text(
                        'N${contribution.amount.formatNumber()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: CoopvestColors.primary,
                        ),
                      ),
                    ],
                  ),
                  // Type
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Type',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondary,
                        ),
                      ),
                      Text(
                        contribution.type.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (contribution.transactionReference != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 14,
                      color: context.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      contribution.transactionReference!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Map<String, String> _parseMonthYear(String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length == 2) {
      try {
        final monthNum = int.parse(parts[1]);
        final year = parts[0];
        final monthName = DateFormat('MMMM').format(DateTime(2024, monthNum));
        return {'month': monthName, 'year': year};
      } catch (e) {
        return {'month': monthYear, 'year': ''};
      }
    }
    return {'month': monthYear, 'year': ''};
  }

  Color _getStatusColor(ContributionStatus status) {
    switch (status) {
      case ContributionStatus.successful:
        return CoopvestColors.success;
      case ContributionStatus.pending:
        return CoopvestColors.warning;
      case ContributionStatus.failed:
        return CoopvestColors.error;
      case ContributionStatus.processing:
        return CoopvestColors.info;
      case ContributionStatus.reversed:
      case ContributionStatus.adjusted:
        return CoopvestColors.warning;
      case ContributionStatus.disputed:
        return CoopvestColors.error;
    }
  }

  Widget _buildErrorState(String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: CoopvestColors.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: context.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Contributions Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your contribution records will appear here',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
