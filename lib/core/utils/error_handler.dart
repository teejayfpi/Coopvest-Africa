import 'package:flutter/material.dart';
import '../utils/utils.dart';

/// Error Handler - Centralized error handling for the app
class ErrorHandler {
  /// Handle error and return user-friendly message
  static String handleError(dynamic error) {
    if (error is AppException) {
      return error.message;
    }
    
    if (error is String) {
      return error;
    }
    
    if (error is FormatException) {
      return 'Invalid data format. Please check your input.';
    }
    
    if (error.toString().contains('Network error')) {
      return 'Network error. Please check your internet connection.';
    }
    
    if (error.toString().contains('Connection refused')) {
      return 'Cannot connect to server. Please try again later.';
    }
    
    if (error.toString().contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    
    logger.e('Unhandled error type: ${error.runtimeType}', error: error);
    return 'An unexpected error occurred. Please try again.';
  }

  /// Show error snackbar
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final message = handleError(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    
    logger.e('Error shown in snackbar: $message');
  }

  /// Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    
    logger.i('Success shown in snackbar: $message');
  }

  /// Show warning snackbar
  static void showWarningSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    
    logger.w('Warning shown in snackbar: $message');
  }

  /// Show loading dialog
  static void showLoadingDialog(BuildContext context, {String message = 'Loading...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Show error dialog
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onButtonPressed,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onButtonPressed?.call();
            },
            child: Text(buttonText ?? 'OK'),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Log error with context
  static void logError(
    String context, {
    required dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extraData,
  }) {
    logger.e(
      'Error in $context',
      error: error,
      stackTrace: stackTrace,
    );
    
    if (extraData != null) {
      logger.d('Extra data: $extraData');
    }
  }

  /// Log network error
  static void logNetworkError(
    String operation, {
    required dynamic error,
    String? endpoint,
  }) {
    logger.e(
      'Network error during $operation',
      error: error,
    );
    
    if (endpoint != null) {
      logger.d('Endpoint: $endpoint');
    }
  }

  /// Handle API error
  static String handleApiError(dynamic response) {
    if (response is Map<String, dynamic>) {
      final message = response['message'] ?? response['error'] ?? 'Unknown API error';
      final code = response['code'];
      
      if (code != null) {
        return 'Error $code: $message';
      }
      return message;
    }
    
    if (response is String) {
      return response;
    }
    
    return 'An API error occurred';
  }

  /// Get error title based on error type
  static String getErrorTitle(dynamic error) {
    if (error is AuthException) {
      return 'Authentication Error';
    }
    
    if (error is NetworkException) {
      return 'Network Error';
    }
    
    if (error is ValidationException) {
      return 'Validation Error';
    }
    
    if (error is ServerException) {
      return 'Server Error';
    }
    
    if (error is SessionExpiredException) {
      return 'Session Expired';
    }
    
    return 'Error';
  }

  /// Check if error requires logout
  static bool requiresLogout(dynamic error) {
    return error is AuthException ||
           error is SessionExpiredException ||
           error is TokenRefreshException;
  }

  /// Check if error is network-related
  static bool isNetworkError(dynamic error) {
    return error is NetworkException ||
           error.toString().contains('Network error') ||
           error.toString().contains('SocketException') ||
           error.toString().contains('connection');
  }
}

/// Result wrapper for operations that can succeed or fail
class Result<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  Result({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory Result.success(T data) {
    return Result(data: data, isSuccess: true);
  }

  factory Result.failure(String error) {
    return Result(error: error, isSuccess: false);
  }

  bool get hasData => data != null;
  bool get hasError => error != null;

  /// Map the success data to another type
  Result<R> map<R>(R Function(T) mapper) {
    if (isSuccess && data != null) {
      return Result.success(mapper(data!));
    }
    return Result.failure(error!);
  }

  /// Execute callback on success
  Result<T> onSuccess(void Function(T) callback) {
    if (isSuccess && data != null) {
      callback(data!);
    }
    return this;
  }

  /// Execute callback on error
  Result<T> onError(void Function(String) callback) {
    if (hasError) {
      callback(error!);
    }
    return this;
  }
}

/// Async result wrapper
class AsyncResult<T> {
  final T? data;
  final String? error;
  final bool isLoading;
  final bool isSuccess;

  AsyncResult({
    this.data,
    this.error,
    this.isLoading = false,
    required this.isSuccess,
  });

  factory AsyncResult.loading() {
    return AsyncResult(isLoading: true, isSuccess: false);
  }

  factory AsyncResult.success(T data) {
    return AsyncResult(data: data, isSuccess: true);
  }

  factory AsyncResult.failure(String error) {
    return AsyncResult(error: error, isSuccess: false);
  }

  bool get hasData => data != null;
  bool get hasError => error != null;
}

/// Error boundary widget for catching widget errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(dynamic error, StackTrace stack) errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    required this.errorBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  dynamic _error;
  StackTrace? _stackTrace;

  void didCatchError(dynamic error, StackTrace stackTrace) {
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });
    
    ErrorHandler.logError(
      'Widget ErrorBoundary',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder(_error, _stackTrace!);
    }
    return widget.child;
  }
}
