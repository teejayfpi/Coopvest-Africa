import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Global error handler widget that catches uncaught exceptions
/// and displays a fallback UI instead of crashing the app.
class GlobalErrorHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback? onError;

  const GlobalErrorHandler({
    super.key,
    required this.child,
    this.onError,
  });

  @override
  State<GlobalErrorHandler> createState() => _GlobalErrorHandlerState();
}

class _GlobalErrorHandlerState extends State<GlobalErrorHandler> {
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Set up global error handling
    WidgetsBinding.instance.addErrorHandler(_handleError);
  }

  void _handleError(dynamic error) {
    setState(() {
      _hasError = true;
      _errorMessage = error?.toString() ?? 'An unknown error occurred';
    });
    widget.onError?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _ErrorFallbackScreen(
        errorMessage: _errorMessage,
        onRetry: () {
          setState(() {
            _hasError = false;
            _errorMessage = '';
          });
        },
      );
    }

    return widget.child;
  }
}

/// Fallback screen shown when an uncaught error occurs.
class _ErrorFallbackScreen extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const _ErrorFallbackScreen({
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text('Close App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error boundary widget for wrapping individual screens/components.
/// Catches errors within its subtree without affecting the whole app.
class ErrorBoundary extends StatelessWidget {
  final Widget child;
  final Widget? errorWidget;
  final VoidCallback? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorWidget,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (e, stackTrace) {
          debugPrint('ErrorBoundary caught: $e\n$stackTrace');
          onError?.call();
          
          if (errorWidget != null) {
            return errorWidget!;
          }
          
          return _ErrorFallbackScreen(
            errorMessage: e.toString(),
            onRetry: () {
              // Rebuild to attempt recovery
              (context as Element).markNeedsBuild();
            },
          );
        }
      },
    );
  }
}