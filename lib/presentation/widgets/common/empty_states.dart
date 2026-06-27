import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';

/// Empty state types for different contexts
enum EmptyStateType {
  noData,
  noResults,
  noTickets,
  noTransactions,
  noLoans,
  noSavings,
  noNotifications,
  noMessages,
  error,
  offline,
}

/// Enhanced empty state widget with themed illustrations
class EnhancedEmptyState extends StatelessWidget {
  final EmptyStateType type;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EnhancedEmptyState({
    super.key,
    required this.type,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIllustration(context),
            const SizedBox(height: 24),
            Text(
              title ?? _defaultTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (subtitle != null || _defaultSubtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle ?? _defaultSubtitle ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CoopvestColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _defaultTitle {
    switch (type) {
      case EmptyStateType.noData:
        return 'No Data Available';
      case EmptyStateType.noResults:
        return 'No Results Found';
      case EmptyStateType.noTickets:
        return 'No Support Tickets';
      case EmptyStateType.noTransactions:
        return 'No Transactions';
      case EmptyStateType.noLoans:
        return 'No Loans';
      case EmptyStateType.noSavings:
        return 'No Savings';
      case EmptyStateType.noNotifications:
        return 'No Notifications';
      case EmptyStateType.noMessages:
        return 'No Messages';
      case EmptyStateType.error:
        return 'Something Went Wrong';
      case EmptyStateType.offline:
        return 'You\'re Offline';
    }
  }

  String? get _defaultSubtitle {
    switch (type) {
      case EmptyStateType.noData:
        return 'Data will appear here when available';
      case EmptyStateType.noResults:
        return 'Try adjusting your search or filters';
      case EmptyStateType.noTickets:
        return 'Your support tickets will appear here';
      case EmptyStateType.noTransactions:
        return 'Your transaction history is empty';
      case EmptyStateType.noLoans:
        return 'Apply for a loan to get started';
      case EmptyStateType.noSavings:
        return 'Start saving to see your progress here';
      case EmptyStateType.noNotifications:
        return 'You\'re all caught up!';
      case EmptyStateType.noMessages:
        return 'No messages yet';
      case EmptyStateType.error:
        return 'Please try again later';
      case EmptyStateType.offline:
        return 'Check your internet connection';
    }
  }

  Widget _buildIllustration(BuildContext context) {
    switch (type) {
      case EmptyStateType.noData:
      case EmptyStateType.noResults:
        return _buildIllustrationIcon(
          context,
          Icons.search_off_rounded,
          Colors.grey,
        );
      case EmptyStateType.noTickets:
        return _buildIllustrationIcon(
          context,
          Icons.support_agent_outlined,
          CoopvestColors.primary,
        );
      case EmptyStateType.noTransactions:
        return _buildIllustrationIcon(
          context,
          Icons.receipt_long_outlined,
          CoopvestColors.success,
        );
      case EmptyStateType.noLoans:
        return _buildIllustrationIcon(
          context,
          Icons.account_balance_outlined,
          CoopvestColors.info,
        );
      case EmptyStateType.noSavings:
        return _buildIllustrationIcon(
          context,
          Icons.savings_outlined,
          CoopvestColors.success,
        );
      case EmptyStateType.noNotifications:
        return _buildIllustrationIcon(
          context,
          Icons.notifications_none_outlined,
          CoopvestColors.warning,
        );
      case EmptyStateType.noMessages:
        return _buildIllustrationIcon(
          context,
          Icons.chat_bubble_outline,
          CoopvestColors.primary,
        );
      case EmptyStateType.error:
        return _buildIllustrationIcon(
          context,
          Icons.error_outline,
          CoopvestColors.error,
        );
      case EmptyStateType.offline:
        return _buildIllustrationIcon(
          context,
          Icons.wifi_off_outlined,
          CoopvestColors.warning,
        );
    }
  }

  Widget _buildIllustrationIcon(
    BuildContext context,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 60,
        color: color,
      ),
    );
  }
}

/// Quick empty state builder for common use cases
class EmptyStateBuilder {
  static Widget build({
    required BuildContext context,
    required EmptyStateType type,
    String? customTitle,
    String? customSubtitle,
    VoidCallback? onRetry,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return EnhancedEmptyState(
      type: type,
      title: customTitle,
      subtitle: customSubtitle,
      onAction: onAction ?? onRetry,
      actionLabel: actionLabel ?? (onRetry != null ? 'Try Again' : null),
    );
  }

  static Widget noData(BuildContext context, {VoidCallback? onRetry}) {
    return build(
      context: context,
      type: EmptyStateType.noData,
      onRetry: onRetry,
    );
  }

  static Widget noResults(BuildContext context) {
    return build(
      context: context,
      type: EmptyStateType.noResults,
    );
  }

  static Widget error(BuildContext context, {VoidCallback? onRetry}) {
    return build(
      context: context,
      type: EmptyStateType.error,
      onRetry: onRetry,
    );
  }

  static Widget offline(BuildContext context, {VoidCallback? onRetry}) {
    return build(
      context: context,
      type: EmptyStateType.offline,
      onRetry: onRetry,
    );
  }

  static Widget noTickets(BuildContext context) {
    return build(
      context: context,
      type: EmptyStateType.noTickets,
    );
  }

  static Widget noTransactions(BuildContext context) {
    return build(
      context: context,
      type: EmptyStateType.noTransactions,
    );
  }

  static Widget noLoans(BuildContext context, {VoidCallback? onApply}) {
    return build(
      context: context,
      type: EmptyStateType.noLoans,
      onAction: onApply,
      actionLabel: onApply != null ? 'Apply for Loan' : null,
    );
  }

  static Widget noSavings(BuildContext context, {VoidCallback? onSave}) {
    return build(
      context: context,
      type: EmptyStateType.noSavings,
      onAction: onSave,
      actionLabel: onSave != null ? 'Start Saving' : null,
    );
  }

  static Widget noNotifications(BuildContext context) {
    return build(
      context: context,
      type: EmptyStateType.noNotifications,
    );
  }
}
