import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';

/// Network error types
enum NetworkErrorType {
  noConnection,
  timeout,
  serverError,
  unauthorized,
  notFound,
  unknown,
}

/// Network error handler widget with retry functionality
class NetworkErrorHandler extends StatelessWidget {
  final NetworkErrorType errorType;
  final String? customMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onLogout;
  final bool showLogoutOption;

  const NetworkErrorHandler({
    super.key,
    required this.errorType,
    this.customMessage,
    this.onRetry,
    this.onLogout,
    this.showLogoutOption = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(),
            const SizedBox(height: 24),
            Text(
              _title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              customMessage ?? _message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  String get _title {
    switch (errorType) {
      case NetworkErrorType.noConnection:
        return 'No Internet Connection';
      case NetworkErrorType.timeout:
        return 'Connection Timeout';
      case NetworkErrorType.serverError:
        return 'Server Error';
      case NetworkErrorType.unauthorized:
        return 'Session Expired';
      case NetworkErrorType.notFound:
        return 'Not Found';
      case NetworkErrorType.unknown:
        return 'Something Went Wrong';
    }
  }

  String get _message {
    switch (errorType) {
      case NetworkErrorType.noConnection:
        return 'Please check your internet connection and try again.';
      case NetworkErrorType.timeout:
        return 'The server took too long to respond. Please try again.';
      case NetworkErrorType.serverError:
        return 'We\'re having trouble connecting to our servers. Please try again later.';
      case NetworkErrorType.unauthorized:
        return 'Your session has expired. Please log in again.';
      case NetworkErrorType.notFound:
        return 'The requested content could not be found.';
      case NetworkErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  IconData get _icon {
    switch (errorType) {
      case NetworkErrorType.noConnection:
        return Icons.wifi_off_outlined;
      case NetworkErrorType.timeout:
        return Icons.timer_off_outlined;
      case NetworkErrorType.serverError:
        return Icons.cloud_off_outlined;
      case NetworkErrorType.unauthorized:
        return Icons.lock_outline;
      case NetworkErrorType.notFound:
        return Icons.search_off_outlined;
      case NetworkErrorType.unknown:
        return Icons.error_outline;
    }
  }

  Color get _iconColor {
    switch (errorType) {
      case NetworkErrorType.noConnection:
        return CoopvestColors.warning;
      case NetworkErrorType.timeout:
        return CoopvestColors.warning;
      case NetworkErrorType.serverError:
        return CoopvestColors.error;
      case NetworkErrorType.unauthorized:
        return CoopvestColors.info;
      case NetworkErrorType.notFound:
        return CoopvestColors.textSecondary;
      case NetworkErrorType.unknown:
        return CoopvestColors.error;
    }
  }

  Widget _buildIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: _iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _icon,
        size: 60,
        color: _iconColor,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        if (onRetry != null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CoopvestColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        if (showLogoutOption && onLogout != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: onLogout,
            child: const Text(
              'Log out and try again',
              style: TextStyle(
                color: CoopvestColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Wrapper widget that handles network errors in a refreshable way
class NetworkErrorWrapper extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final bool showRefreshOnError;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  const NetworkErrorWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.showRefreshOnError = true,
    this.errorWidget,
    this.loadingWidget,
  });

  @override
  State<NetworkErrorWrapper> createState() => _NetworkErrorWrapperState();
}

class _NetworkErrorWrapperState extends State<NetworkErrorWrapper> {
  bool _isRefreshing = false;
  bool _hasError = false;
  NetworkErrorType? _errorType;
  String? _errorMessage;

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
      _hasError = false;
    });

    try {
      await widget.onRefresh();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorType = _getErrorType(e);
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  NetworkErrorType _getErrorType(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('connection') || errorStr.contains('network')) {
      return NetworkErrorType.noConnection;
    } else if (errorStr.contains('timeout')) {
      return NetworkErrorType.timeout;
    } else if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return NetworkErrorType.unauthorized;
    } else if (errorStr.contains('404') || errorStr.contains('not found')) {
      return NetworkErrorType.notFound;
    } else if (errorStr.contains('500') || errorStr.contains('server')) {
      return NetworkErrorType.serverError;
    }
    return NetworkErrorType.unknown;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && widget.errorWidget == null) {
      return NetworkErrorHandler(
        errorType: _errorType ?? NetworkErrorType.unknown,
        customMessage: _errorMessage,
        onRetry: _handleRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: _hasError && widget.errorWidget != null
          ? widget.errorWidget!
          : widget.child,
    );
  }
}

/// Pull to refresh wrapper with loading state
class PullToRefreshWrapper extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? refreshColor;
  final Color? backgroundColor;

  const PullToRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: refreshColor ?? CoopvestColors.primary,
      backgroundColor: backgroundColor ?? Colors.white,
      child: child,
    );
  }
}
