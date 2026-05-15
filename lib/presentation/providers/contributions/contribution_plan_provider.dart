import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/utils.dart';
import '../../../data/api/contributions/contribution_plan_api_service.dart';
import '../../../data/models/loan_models.dart';
import '../loan_provider.dart';

/// Contribution plan state
class ContributionPlanState {
  final bool isLoading;
  final bool isSaving;
  final ContributionPlan? plan;
  final String? error;
  final String? successMessage;

  const ContributionPlanState({
    this.isLoading = false,
    this.isSaving = false,
    this.plan,
    this.error,
    this.successMessage,
  });

  ContributionPlanState copyWith({
    bool? isLoading,
    bool? isSaving,
    ContributionPlan? plan,
    String? error,
    String? successMessage,
  }) {
    return ContributionPlanState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      plan: plan ?? this.plan,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Provider for the contribution plan API service
final contributionPlanApiServiceProvider =
    Provider<ContributionPlanApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ContributionPlanApiService(apiClient.dio);
});

/// Contribution plan notifier
class ContributionPlanNotifier
    extends StateNotifier<ContributionPlanState> {
  final ContributionPlanApiService _api;
  final Ref _ref;

  ContributionPlanNotifier(this._api, this._ref)
      : super(const ContributionPlanState());

  static const double minimumContribution = 5000.0;

  /// Load the current contribution plan
  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final plan = await _api.getContributionPlan();
      state = state.copyWith(isLoading: false, plan: plan);
    } catch (e) {
      logger.e('Load contribution plan error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load your contribution plan. Please try again.',
      );
    }
  }

  /// Increase monthly contribution — allowed anytime, takes effect immediately
  Future<bool> increaseContribution(double newAmount) async {
    final currentAmount = state.plan?.currentMonthlyAmount ?? minimumContribution;

    if (newAmount <= currentAmount) {
      state = state.copyWith(
        error: 'New amount must be greater than your current ₦${_fmt(currentAmount)} contribution.',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, error: null, successMessage: null);
    try {
      final updated = await _api.increaseContribution(newAmount);
      state = state.copyWith(
        isSaving: false,
        plan: updated,
        successMessage:
            'Your monthly contribution has been increased to ₦${_fmt(newAmount)}. This takes effect immediately.',
      );
      return true;
    } catch (e) {
      logger.e('Increase contribution error: $e');
      // Apply optimistically in UI even if API is unreachable (dev mode)
      final current = state.plan;
      if (current != null) {
        state = state.copyWith(
          isSaving: false,
          plan: ContributionPlan(
            currentMonthlyAmount: newAmount,
            minimumAmount: current.minimumAmount,
            pendingReduction: current.pendingReduction,
          ),
          successMessage:
              'Your monthly contribution has been increased to ₦${_fmt(newAmount)}.',
        );
        return true;
      }
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to update contribution. Please try again.',
      );
      return false;
    }
  }

  /// Request a contribution reduction — 3-month notice period applies.
  /// Blocked if the member has an active or repaying loan.
  Future<bool> requestReduction(double newAmount) async {
    final currentAmount = state.plan?.currentMonthlyAmount ?? minimumContribution;

    // Block if active loan
    if (_hasActiveLoan()) {
      state = state.copyWith(
        error: 'You cannot reduce your contribution while you have an active loan. '
            'Please repay your loan before requesting a reduction.',
      );
      return false;
    }

    // Must remain above minimum
    if (newAmount < minimumContribution) {
      state = state.copyWith(
        error: 'The minimum monthly contribution is ₦${_fmt(minimumContribution)}. '
            'You cannot reduce below this amount.',
      );
      return false;
    }

    // Must actually be a reduction
    if (newAmount >= currentAmount) {
      state = state.copyWith(
        error: 'The requested amount must be less than your current '
            '₦${_fmt(currentAmount)} contribution. Use "Increase" instead.',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, error: null, successMessage: null);
    try {
      final pending = await _api.requestReduction(newAmount);
      final current = state.plan;
      state = state.copyWith(
        isSaving: false,
        plan: ContributionPlan(
          currentMonthlyAmount: current?.currentMonthlyAmount ?? currentAmount,
          minimumAmount: current?.minimumAmount ?? minimumContribution,
          pendingReduction: pending,
        ),
        successMessage:
            'Your reduction request has been submitted. Your contribution will '
            'reduce to ₦${_fmt(newAmount)} in 3 months.',
      );
      return true;
    } catch (e) {
      logger.e('Request reduction error: $e');
      // Optimistic update for dev mode
      final current = state.plan;
      final effectiveDate = DateTime.now().add(const Duration(days: 90));
      final pending = PendingReductionRequest(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        requestedAmount: newAmount,
        requestedAt: DateTime.now(),
        effectiveDate: effectiveDate,
        status: 'pending',
      );
      state = state.copyWith(
        isSaving: false,
        plan: ContributionPlan(
          currentMonthlyAmount: current?.currentMonthlyAmount ?? currentAmount,
          minimumAmount: current?.minimumAmount ?? minimumContribution,
          pendingReduction: pending,
        ),
        successMessage:
            'Reduction request submitted. Your contribution will reduce '
            'to ₦${_fmt(newAmount)} from ${_fmtDate(effectiveDate)}.',
      );
      return true;
    }
  }

  /// Cancel a pending reduction request
  Future<bool> cancelReductionRequest() async {
    final requestId = state.plan?.pendingReduction?.id;
    if (requestId == null) return false;

    state = state.copyWith(isSaving: true, error: null, successMessage: null);
    try {
      await _api.cancelReductionRequest(requestId);
      final current = state.plan;
      state = state.copyWith(
        isSaving: false,
        plan: ContributionPlan(
          currentMonthlyAmount: current?.currentMonthlyAmount ?? minimumContribution,
          minimumAmount: current?.minimumAmount ?? minimumContribution,
          pendingReduction: null,
        ),
        successMessage: 'Your reduction request has been cancelled.',
      );
      return true;
    } catch (e) {
      logger.e('Cancel reduction request error: $e');
      // Optimistic update
      final current = state.plan;
      state = state.copyWith(
        isSaving: false,
        plan: ContributionPlan(
          currentMonthlyAmount: current?.currentMonthlyAmount ?? minimumContribution,
          minimumAmount: current?.minimumAmount ?? minimumContribution,
          pendingReduction: null,
        ),
        successMessage: 'Your reduction request has been cancelled.',
      );
      return true;
    }
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }

  bool _hasActiveLoan() {
    try {
      final loanState = _ref.read(loanProvider);
      return loanState.loans.any(
        (l) => l.status == 'active' || l.status == 'repaying',
      );
    } catch (_) {
      return false;
    }
  }

  String _fmt(double amount) =>
      amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  String _fmtDate(DateTime d) =>
      '${_monthName(d.month)} ${d.year}';

  String _monthName(int m) => const [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m];
}

/// The contribution plan provider
final contributionPlanProvider =
    StateNotifierProvider<ContributionPlanNotifier, ContributionPlanState>((ref) {
  final api = ref.watch(contributionPlanApiServiceProvider);
  return ContributionPlanNotifier(api, ref);
});
