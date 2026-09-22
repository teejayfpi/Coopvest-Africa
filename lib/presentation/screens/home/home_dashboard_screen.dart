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
import '../../../presentation/widgets/common/announcement_marquee.dart';
import '../../../presentation/widgets/common/announcement_popup.dart';
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

  /// Whether the member has hidden their balances. Purely local UI state —
  /// it hides the figures behind dots so a member can open the app in public
  /// without exposing their money. Not persisted: reopening shows balances.
  bool _balanceHidden = false;

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
        // Announcements drive both the news ticker and the popups, so load them
        // with the rest rather than making the marquee fetch separately.
        ref.read(announcementProvider.notifier).loadAnnouncements(),
      ]);

      // Surface any popup announcements now that they are loaded. Runs after the
      // fetch so a popup never appears for content the member cannot see.
      if (mounted) {
        unawaited(AnnouncementPopupHost.checkAndShow(context, ref));
      }

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

              // Scrolling admin news. Renders nothing when no announcement is
              // configured as a marquee, so the layout is unchanged otherwise.
              const SizedBox(height: 8),
              AnnouncementMarquee(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
                ),
              ),
              
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
                              walletBalance.formatCurrencyCompact(),
                              Icons.account_balance_wallet_outlined,
                              () => Navigator.push(context, MaterialPageRoute(builder: (context) => WalletDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? ''))),
                              accentColor: CoopvestColors.primary,
                              chipTint: CoopvestColors.iconTintGreen,
                              isZero: walletBalance <= 0,
                              zeroHint: 'Add money →',
                              onZeroTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen(userId: user?.id ?? ''))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactStatCard(
                              context,
                              'Savings',
                              (wallet?.totalSavings ?? 0.0).formatCurrencyCompact(),
                              Icons.savings_outlined,
                              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MonthlyContributionsScreen())),
                              accentColor: CoopvestColors.primaryLight,
                              chipTint: CoopvestColors.iconTintMint,
                              isZero: (wallet?.totalSavings ?? 0.0) <= 0,
                              zeroHint: 'Start saving →',
                              onZeroTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen(userId: user?.id ?? ''))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactStatCard(
                              context,
                              'Loans',
                              activeLoans.formatCurrencyCompact(),
                              Icons.monetization_on_outlined,
                              () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDashboardScreen(userId: user?.id ?? '', userName: user?.name ?? '', userPhone: user?.phone ?? ''))),
                              // Loans is the gold card: gold chip, deepened
                              // gold icon and link so it stays legible on white.
                              accentColor: CoopvestColors.accentIcon,
                              chipTint: CoopvestColors.iconTintGold,
                              isZero: activeLoans <= 0,
                              zeroHint: 'Apply now →',
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
                            // Gold, matching the Loans card. Uses the deepened
                            // gold so the icon stays legible on the light chip.
                            color: CoopvestColors.accentIcon,
                            chipTint: CoopvestColors.iconTintGold,
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
                            // Mint chip = growth.
                            color: CoopvestColors.primaryLight,
                            chipTint: CoopvestColors.iconTintMint,
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
      decoration: const BoxDecoration(
        // Flat single emerald, no gradient and no drop shadow — depth comes
        // from the shape (24px bottom corners) and the summary cards that
        // overlap it, not from elevation.
        color: CoopvestColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(CoopvestShape.headerRadius),
          bottomRight: Radius.circular(CoopvestShape.headerRadius),
        ),
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
                    // Tappable pill: shows the member ID and toggles balance
                    // visibility. Previously the eye was decorative and did
                    // nothing when tapped.
                    GestureDetector(
                      onTap: () =>
                          setState(() => _balanceHidden = !_balanceHidden),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: CoopvestColors.headerChip,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            // The icon mirrors the state so it is not a
                            // one-way action: filled eye = visible.
                            Icon(
                              _balanceHidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ID: $membershipId',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Balance. Hidden state shows dots rather than ₦0 so a member
                // who hides the figure does not accidentally read it as zero,
                // and long values abbreviate (₦1.2M) to stay on one line.
                Text(
                  _balanceHidden
                      ? NumberExtensions.hiddenAmount
                      : totalSavings.formatCurrencyCompact(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  totalSavings > 0
                      ? 'Updated just now'
                      : 'Make your first contribution',
                  style: const TextStyle(
                    color: CoopvestColors.headerNudge,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: CoopvestShape.gapLg),
                // Divider between the headline figure and the stat rows.
                Container(height: 1, color: CoopvestColors.headerDivider),
                const SizedBox(height: CoopvestShape.gapLg),
                // Breakdown summary — monthly savings, outstanding loan and
                // total loan applied, so members see the full picture at a glance.
                _buildHeaderSummaryRow(
                  context,
                  'Total Savings',
                  _balanceHidden ? NumberExtensions.hiddenAmount : totalSavings.formatCurrencyCompact(),
                  icon: Icons.savings_outlined,
                ),
                const SizedBox(height: 10),
                _buildHeaderSummaryRow(
                  context,
                  'Outstanding Loan',
                  _balanceHidden ? NumberExtensions.hiddenAmount : outstandingLoan.formatCurrencyCompact(),
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 10),
                _buildHeaderSummaryRow(
                  context,
                  'Total Loan Applied',
                  _balanceHidden ? NumberExtensions.hiddenAmount : totalLoanApplied.formatCurrencyCompact(),
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 10),
                _buildHeaderSummaryRow(
                  context,
                  'Available to Withdraw',
                  _balanceHidden ? NumberExtensions.hiddenAmount : (wallet?.availableForWithdrawal ?? 0.0).formatCurrencyCompact(),
                  icon: Icons.account_balance_outlined,
                ),
                const SizedBox(height: CoopvestShape.gapLg),
                // Quick actions row — fills the empty green space and gives
                // users the two most common wallet actions one tap away.
                Row(
                  children: [
                    Expanded(
                      child: _buildHeaderActionChip(
                        label: 'Add money',
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
            Icon(icon, color: CoopvestColors.headerLabel, size: 15),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: CoopvestColors.headerLabel,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            // Values are always white; only the row label is muted, so the
            // figure is the loudest thing in the row.
            color: valueColor ?? Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
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
    // Exactly one gold action per screen: `filled` is the gold primary
    // ("Add money"). The secondary is a transparent outline. Gold always
    // carries dark text — white on gold is only 1.82:1.
    final bg = filled ? CoopvestColors.accent : Colors.transparent;
    final fg = filled ? CoopvestColors.onAccent : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CoopvestShape.buttonRadius),
        child: Container(
          height: CoopvestShape.minTouchTarget,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(CoopvestShape.buttonRadius),
            border: filled
                ? null
                : Border.all(color: CoopvestColors.headerOutline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: fg,
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
    Color chipTint = CoopvestColors.iconTintGreen,
    Color? iconColor,
    Color? linkColor,
  }) {
    final cardColor = accentColor ?? CoopvestColors.primary;
    final effectiveIcon = iconColor ?? cardColor;
    final effectiveLink = linkColor ?? cardColor;

    return GestureDetector(
      onTap: isZero && onZeroTap != null ? onZeroTap : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        // Flat, bordered card — the brief's single card style. No shadow and
        // no coloured gradient: only the icon tint and the link colour vary
        // between the three cards.
        decoration: CoopvestShape.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: CoopvestShape.iconChip(chipTint),
              child: Icon(icon, color: effectiveIcon, size: 22),
            ),
            const SizedBox(height: CoopvestShape.gapMd),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CoopvestShape.gapSm),
            Text(
              value,
              style: TextStyle(
                // Card amount: 16/medium per the type scale.
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isZero ? context.textSecondary : context.textPrimary,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isZero && zeroHint != null) ...[
              const SizedBox(height: CoopvestShape.gapSm),
              // The link uses its own AA-safe colour: emerald reads fine on
              // white, but gold must darken to #8A6300 to stay legible.
              Row(
                children: [
                  Text(
                    zeroHint,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: effectiveLink,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward_rounded, size: 13, color: effectiveLink),
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
    Color chipTint = CoopvestColors.iconTintGreen,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CoopvestShape.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: CoopvestShape.gapMd,
            horizontal: CoopvestShape.gapSm,
          ),
          decoration: CoopvestShape.cardDecoration(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Circular chip, single flat tint — no gradient.
              Container(
                padding: const EdgeInsets.all(10),
                decoration:
                    CoopvestShape.iconChip(chipTint, circular: true),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: CoopvestShape.gapSm),
              SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textPrimary,
                      fontWeight: FontWeight.w500,
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
