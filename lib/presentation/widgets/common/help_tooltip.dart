import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';

/// A reusable help tooltip widget that shows contextual help information
class HelpTooltip extends StatelessWidget {
  final String message;
  final Widget? child;
  final TooltipPosition position;

  const HelpTooltip({
    super.key,
    required this.message,
    this.child,
    this.position = TooltipPosition.top,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      preferBelow: position == TooltipPosition.bottom,
      decoration: BoxDecoration(
        color: CoopvestColors.primary.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: child ?? Icon(
        Icons.help_outline,
        color: CoopvestColors.primary.withOpacity(0.7),
        size: 20,
      ),
    );
  }
}

enum TooltipPosition { top, bottom }

/// A more feature-rich tooltip with icon trigger
class ContextualHelp extends StatelessWidget {
  final String title;
  final String content;
  final IconData? icon;

  const ContextualHelp({
    super.key,
    required this.title,
    required this.content,
    this.icon,
  });

  void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon ?? Icons.help_outline, color: CoopvestColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon ?? Icons.help_outline, color: CoopvestColors.primary),
      onPressed: () => show(context),
      tooltip: title,
    );
  }
}

/// Feature highlight widget - shows a guided highlight for new features
class FeatureHighlight extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onDismiss;

  const FeatureHighlight({
    super.key,
    required this.title,
    required this.description,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CoopvestColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CoopvestColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: CoopvestColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: CoopvestColors.primary,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
