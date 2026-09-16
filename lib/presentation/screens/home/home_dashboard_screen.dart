import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../core/services/contribution_reminder_service.dart';
// contributionReminderService is a singleton, no Provider needed
import '../../../data/models/wallet_models.dart';
import '../../../data/models/loan_models.dart';
import '../../../data/models/announcement_models.dart';
import '../../../data/models/guarantor_models.dart';
import '../../../data/models/document_models.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/wallet_provider.dart';
import '../../../presentation/providers/loan_provider.dart';
import '../../../presentation/providers/contributions/contribution_provider.dart';
import '../../../presentation/providers/notifications_provider.dart';
import 'notifications_screen.dart';
import '../../../core/services/realtime_notification_service.dart';
import '../../../data/models/notification_models.dart';
import '../../../presentation/providers/deposit_history_provider.dart';
import '../../../presentation/providers/announcement_provider.dart';
import '../../../presentation/providers/guarantor_provider.dart';
import '../../../presentation/providers/document_provider.dart';
import '../../../presentation/screens/wallet/deposit_screen.dart';
import '../../../presentation/screens/wallet/withdrawal_screen.dart';
import '../../../presentation/screens/loan/loan_dashboard_screen.dart';
import '../../../presentation/screens/wallet/wallet_dashboard_screen.dart';
import '../../../presentation/screens/referral/referral_dashboard_screen.dart';
import '../../../presentation/screens/contributions/monthly_contributions_screen.dart';
import '../../../presentation/screens/transactions/transactions_history_screen.dart';
import '../../../presentation/screens/announcements/announcements_screen.dart';
import '../../../presentation/screens/guarantor/guarantor_dashboard_screen.dart';
import '../../../presentation/screens/documents/document_upload_screen.dart';
import '../../../presentation/screens/profile/profile_settings_screen.dart';

import '../../../presentation/widgets/loan/loan_eligibility_card.dart';
import '../../../presentation/widgets/obligations_card.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen>
    with WidgetsBindingObserver {
  late Future<void> _refreshFuture;
  Timer? _refreshTimer;
  bool _appInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshFuture = _loadData();
    _startPeriodicRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeToNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPeriodicRefresh();
    RealtimeNotificationService().unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      _startPeriodicRefresh();
      _loadData();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _appInForeground = false;
      _stopPeriodicRefresh();
    }
  }

  void _startPeriodicRefresh() {
    _stopPeriodicRefresh();
    // Refresh every 60 seconds only while the app is in the foreground
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && _appInForeground) {
        _loadData();
      }
    });
  }

  void _stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _subscribeToNotifications() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final service = RealtimeNotificationService();
    service.onNewNotification = (Map<String, dynamic> row) {
      if (!mounted) return;
      try {
        final notification = AppNotification.fromJson(row);
        ref.read(notificationsProvider.notifier).addNotification(notification);
        // Refresh deposit history for wallet events so status screen stays current
        final type = row['type'] as String? ?? '';
        if (type == 'wallet_credited' ||
            type == 'deposit_rejected' ||
            type == 'payment_proof_approved') {
          ref.read(depositHistoryProvider.notifier).load();
          ref.read(walletProvider.notifier).loadWallet();
        }
      } catch (e) {
        // ignore parse errors
      }
    };

    service.subscribe(user.id);
  }

  Future<void> _loadData() async {
    try {
      // Load all required data in parallel
      await Future.wait([
        ref.read(walletProvider.notifier).loadWallet(),
        ref.read(loanProvider.notifier).getLoans(),
        ref.read(contributionProvider.notifier).loadContributions(),
        ref.read(notificationsProvider.notifier).loadNotifications(),
      ]);

      // Re-fetch obligations. The obligations card reads a FutureProvider that
      // is otherwise cached forever, so without this the "Monthly Savings"
      // figure keeps showing the amount from app start — a member who raises
      // their contribution only saw it after a restart.
      ref.invalidate(obligationsProvider);

      // Fetch recent transactions for the home preview (non-blocking).
      ref.read(walletProvider.notifier).loadTransactions(page: 1, pageSize: 5);

      // Check and send contribution reminders after data is loaded
      _checkContributionReminders();
    } catch (e) {
      if (mounted) {
        debugPrint('Error loading dashboard data: $e');
      }
    }
  }

  void _checkContributionReminders() {
    final user = ref.read(currentUserProvider);
    final walletState = ref.read(walletProvider);
    final contributionState = ref.read(contributionProvider);

    if (user == null) return;

    // Get user's contribution method from settings
    // Default to 'manual' if not set (assume manual until proven payroll)
    const contributionMethod = 'manual';
    
    // Use defaults - backend will have accurate user preferences
    const preferredDay = 5; // Default to 5th of month
    const monthlyAmount = 5000.0; // Minimum contribution

    // Use singleton service
    contributionReminderService.checkAndSendReminders(
      contributions: contributionState.contributions,
      monthlyAmount: monthlyAmount,
      preferredDay: preferredDay,
      totalSavings: walletState.wallet?.totalContributions ?? 0.0,
    );

    // Sync status with backend for cron job processing
    contributionReminderService.syncContributionStatus(
      userId: user.id,
      contributions: contributionState.contributions,
      monthlyAmount: monthlyAmount,
      preferredDay: preferredDay,
      contributionMethod: contributionMethod,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    // True when this member's contributions arrive via employer payroll rather
    // than being paid in-app; drives the contribution CTA below.
    final onSalaryDeduction = user?.onSalaryDeduction ?? false;
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;
    final loansState = ref.watch(loanProvider);
    
    final userName = user?.name.split(' ').first ?? 'User';
    final membershipId = user?.id.substring(0, 6) ?? 'N/A';
    
    final walletBalance = wallet?.balance ?? 0.0;
    final totalContributions = wallet?.totalContributions ?? 0.0;
    final activeLoans = loansState.loans
        .where((l) => isLoanActive(l.status))
        .fold(0.0, (sum, l) => sum + l.amount);

    final recentTransactions = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: CoopvestColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context, userName, membershipId, user?.name ?? 'User', user?.id ?? '', loansState),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stat Cards - Overlapping
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildCompactStatCard(
                              context,
                              'Wallet',
                              '₦${walletBalance.formatNumber()}',
                              Icons.account_balance_wallet_outlined,
                              () => Navigator.push(context, MaterialPageRoute(builder: (context) => WalletDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? ''))),
                              accentColor: CoopvestColors.primary,
                              isZero: walletBalance <= 0,
                              zeroHint: 'Add Money',
                              onZeroTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen(userId: user?.id ?? ''))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactStatCard(
                              context,
                              'Savings',
                              '₦${(wallet?.totalSavings ?? 0.0).formatNumber()}',
                              Icons.savings_outlined,
                              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MonthlyContributionsScreen())),
                              accentColor: const Color(0xFF2E7D32),
                              isZero: (wallet?.totalSavings ?? 0.0) <= 0,
                              zeroHint: 'Start saving',
                              onZeroTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen(userId: user?.id ?? ''))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactStatCard(
                              context,
                              'Loans',
                              '₦${activeLoans.formatNumber()}',
                              Icons.monetization_on_outlined,
                              () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? '', userPhone: user?.phone ?? ''))),
                              accentColor: const Color(0xFF1565C0),
                              isZero: activeLoans <= 0,
                              zeroHint: 'Apply now',
                              onZeroTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? '', userPhone: user?.phone ?? ''))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),

                    // Quick Actions — primary member shortcuts, one tap away.
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 10),
                      child: Row(
                        children: [
                          Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action Buttons Row — 3 evenly-sized cards that fill the row.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            context,
                            // Salary-deduction members do not pay themselves: their
                            // employer deducts at source and finance posts the
                            // remittance. Offering "Make Contribution" led them into
                            // a payment flow that double-credits money they never
                            // paid. Show where their contribution actually comes from
                            // and open their history instead.
                            onSalaryDeduction ? 'View Contributions' : 'Make Contribution',
                            onSalaryDeduction ? Icons.receipt_long_outlined : Icons.payments_outlined,
                            () {
                              if (onSalaryDeduction) {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const MonthlyContributionsScreen()));
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen(userId: user?.id ?? '')));
                              }
                            },
                            color: CoopvestColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildActionButton(
                            context,
                            'Apply for Loan',
                            Icons.description_outlined,
                            () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? '', userPhone: user?.phone ?? ''))),
                            color: const Color(0xFF1565C0), // matches the Loans card
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildActionButton(
                            context,
                            'Investment Pool',
                            Icons.trending_up_outlined,
                            () => ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Investment Pool coming soon'),
                                backgroundColor: CoopvestColors.primary,
                              ),
                            ),
                            color: const Color(0xFF00897B), // teal = growth
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Your obligations this month — sits directly under the
                    // Quick Actions so the member sees what is due and can pay
                    // it without leaving the dashboard.
                    const ObligationsCard(),

                    const SizedBox(height: 24),

                    // Recent Activity preview — what users check right after balance.
                    _buildRecentActivitySection(
                      context,
                      recentTransactions,
                      user?.id ?? '',
                    ),

                    const SizedBox(height: 20),

                    // Loan Eligibility Progress
                    LoanEligibilityCard(
                      onApplyTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoanDashboardScreen(
                            userId: user?.id ?? '',
                            userName: user?.name ?? '',
                            userPhone: user?.phone ?? '',
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                    
                    // Notifications Section - Real-time from provider
                    _buildNotificationsSection(context, user?.id ?? ''),

                    // Extra bottom padding so the last card clears the bottom nav
                    // and isn't half-hidden when scrolled to the end.
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, String membershipId, String fullName, String userId, LoansState loansState) {
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;

    // Total Balance (headline) = the member's lifetime monthly savings.
    // `total_savings` is only ever incremented by approved monthly savings
    // contributions/deposits — loans and fees are never added to it.
    final totalSavings = wallet?.totalSavings ?? 0.0;

    // Outstanding loan = what's still owed on active/approved/repaying loans.
    final outstandingLoan = loansState.loans
        .where((l) => isLoanActive(l.status))
        .fold(0.0, (sum, l) => sum + l.remainingBalance);

    // Total loan applied = original amount of loans still in the pipeline
    // (not yet completed, rejected or cancelled) so the figure returns to 0
    // once every loan is fully repaid.
    final totalLoanApplied = loansState.loans
        .where((l) => !const ['completed', 'rejected', 'cancelled'].contains(l.status))
        .fold(0.0, (sum, l) => sum + l.amount);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 60),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B5E20),
            const Color(0xFF2E7D32),
            const Color(0xFF388E3C),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with greeting and avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Notification bell
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Avatar
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileSettingsScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: ref.watch(currentUserProvider)?.profilePicture != null && ref.watch(currentUserProvider)!.profilePicture!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                ref.watch(currentUserProvider)!.profilePicture!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    child: Text(
                                      _getInitials(fullName),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              child: Text(
                                _getInitials(fullName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 28),
          
          // Total Balance Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Balance',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            color: Colors.white.withOpacity(0.9),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ID: $membershipId',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '₦${totalSavings.formatNumber()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                // Growth indicator - only show if there's actual data
                if (totalSavings > 0)
                  Text(
                    'Updated just now',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    'Make your first contribution',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 18),
                // Breakdown summary — monthly savings, outstanding loan and
                // total loan applied, so members see the full picture at a glance.
                _buildHeaderSummaryRow(
                  context,
                  'Total Savings',
                  '\u20a6${totalSavings.formatNumber()}',
                  icon: Icons.savings_outlined,
                ),
                const SizedBox(height: 10),
                _buildHeaderSummaryRow(
                  context,
                  'Outstanding Loan',
                  '\u20a6${outstandingLoan.formatNumber()}',
                  icon: Icons.account_balance_wallet_outlined,
                  valueColor: outstandingLoan > 0 ? const Color(0xFFFFCC80) : Colors.white.withOpacity(0.9),
                ),
                const SizedBox(height: 10),
                _buildHeaderSummaryRow(
                  context,
                  'Total Loan Applied',
                  '\u20a6${totalLoanApplied.formatNumber()}',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 10),
                _buildHeaderSummaryRow(
                  context,
                  'Available to Withdraw',
                  '\u20a6${(wallet?.availableForWithdrawal ?? 0.0).formatNumber()}',
                  icon: Icons.account_balance_outlined,
                ),
                const SizedBox(height: 18),
                // Quick actions row — fills the empty green space and gives
                // users the two most common wallet actions one tap away.
                Row(
                  children: [
                    Expanded(
                      child: _buildHeaderActionChip(
                        label: 'Add Money',
                        icon: Icons.add_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DepositScreen(userId: userId),
                          ),
                        ),
                        filled: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHeaderActionChip(
                        label: 'Withdraw',
                        icon: Icons.north_east_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WithdrawalScreen(userId: userId),
                          ),
                        ),
                        filled: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSummaryRow(
    BuildContext context,
    String label,
    String value, {
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.7), size: 15),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderActionChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: filled
                ? Colors.white
                : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(filled ? 0.0 : 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled ? CoopvestColors.primary : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: filled ? CoopvestColors.primary : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Widget _buildCompactStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    VoidCallback onTap, {
    Color? accentColor,
    bool isZero = false,
    String? zeroHint,
    VoidCallback? onZeroTap,
  }) {
    final cardColor = accentColor ?? CoopvestColors.primary;

    return GestureDetector(
      onTap: isZero && onZeroTap != null ? onZeroTap : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: cardColor.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cardColor.withOpacity(0.15),
                    cardColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: cardColor, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isZero ? context.textSecondary : context.textPrimary,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isZero && zeroHint != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    zeroHint,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cardColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: cardColor,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, {
    Color color = CoopvestColors.primary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: color.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.16),
                      color.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(
    BuildContext context,
    List<Transaction> transactions,
    String userId,
  ) {
    final recent = transactions.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TransactionsHistoryScreen(userId: userId),
                ),
              ),
              child: Text(
                'See all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CoopvestColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.dividerColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CoopvestColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: CoopvestColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No transactions yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your deposits, withdrawals and contributions will show here.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: context.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: Colors.grey.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < recent.length; i++) ...[
                  _buildRecentActivityTile(context, recent[i], userId),
                  if (i < recent.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      color: context.dividerColor.withOpacity(0.4),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRecentActivityTile(
    BuildContext context,
    Transaction txn,
    String userId,
  ) {
    final isCredit = txn.isCredit;
    final accent = isCredit ? CoopvestColors.success : CoopvestColors.warning;
    final icon = isCredit
        ? Icons.south_west_rounded
        : Icons.north_east_rounded;

    final label = (txn.description?.isNotEmpty ?? false)
        ? txn.description!
        : _transactionTypeLabel(txn.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionsHistoryScreen(userId: userId),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimeAgo(txn.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isCredit ? '+' : '-'}₦${txn.amount.formatNumber()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _transactionTypeLabel(String type) {
    switch (type) {
      case 'deposit':
      case 'contribution':
        return 'Contribution';
      case 'withdrawal':
        return 'Withdrawal';
      case 'transfer_in':
        return 'Transfer in';
      case 'transfer_out':
        return 'Transfer out';
      case 'interest':
        return 'Interest';
      case 'loan_repayment':
        return 'Loan repayment';
      case 'loan_disbursement':
        return 'Loan disbursement';
      case 'refund':
        return 'Refund';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  Widget _buildNotificationItem(BuildContext context, String title, String time, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: Colors.grey.withOpacity(0.06),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.15),
                      color.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (time.isNotEmpty) ...[ 
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.textSecondary.withOpacity(0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context, String userId) {
    final notificationsState = ref.watch(notificationsProvider);
    final notifications = notificationsState.notifications.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notifications',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (notifications.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.dividerColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CoopvestColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_none_outlined,
                    color: CoopvestColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your notifications will appear here',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...notifications.map((notification) {
            final isLoan = notification.type.contains('loan');
            final isContribution = notification.type.contains('contribution');
            final icon = isLoan 
                ? Icons.monetization_on_outlined 
                : (isContribution ? Icons.savings_outlined : Icons.notifications_outlined);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildNotificationItem(
                context,
                notification.title,
                _formatTimeAgo(notification.timestamp),
                icon,
                CoopvestColors.primary,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                ),
              ),
            );
          }),
      ],
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}
