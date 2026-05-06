import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/feature_service.dart';

/// A widget that only shows its child if the feature is enabled
class FeatureGate extends ConsumerWidget {
  final String featureName;
  final Widget child;
  final Widget? fallback;
  final bool requireAllFeatures;
  final List<String> features;

  const FeatureGate({
    super.key,
    required this.featureName,
    required this.child,
    this.fallback,
    this.requireAllFeatures = true,
    this.features = const [],
  });

  const FeatureGate.any({
    super.key,
    required this.features,
    required this.child,
    this.fallback,
  })  : featureName = '',
        requireAllFeatures = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureService = ref.read(featureServiceProvider);
    
    final isEnabled = requireAllFeatures
        ? featureService.isEnabled(featureName)
        : features.any((f) => featureService.isEnabled(f));

    if (isEnabled) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

/// A widget that shows a disabled feature placeholder
class FeatureDisabledPlaceholder extends StatelessWidget {
  final String featureName;
  final String? message;
  final VoidCallback? onTap;

  const FeatureDisabledPlaceholder({
    super.key,
    required this.featureName,
    this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FeatureService.featureNames[featureName] ?? featureName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (message != null)
                    Text(
                      message!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

/// A button that is disabled when feature is not enabled
class FeatureButton extends ConsumerWidget {
  final String featureName;
  final Widget child;
  final VoidCallback onPressed;
  final bool requireAllFeatures;
  final List<String> features;

  const FeatureButton({
    super.key,
    required this.featureName,
    required this.child,
    required this.onPressed,
    this.requireAllFeatures = true,
    this.features = const [],
  });

  const FeatureButton.any({
    super.key,
    required this.features,
    required this.child,
    required this.onPressed,
  })  : featureName = '',
        requireAllFeatures = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureService = ref.read(featureServiceProvider);
    
    final isEnabled = requireAllFeatures
        ? featureService.isEnabled(featureName)
        : features.any((f) => featureService.isEnabled(f));

    return AbsorbPointer(
      absorbing: !isEnabled,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          child: child,
        ),
      ),
    );
  }
}

/// Feature-aware list tile that shows/hides based on feature status
class FeatureListTile extends ConsumerWidget {
  final String featureName;
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onTap;
  final bool requireAllFeatures;
  final List<String> features;

  const FeatureListTile({
    super.key,
    required this.featureName,
    required this.leading,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.requireAllFeatures = true,
    this.features = const [],
  });

  const FeatureListTile.any({
    super.key,
    required this.features,
    required this.leading,
    required this.title,
    this.subtitle,
    required this.onTap,
  })  : featureName = '',
        requireAllFeatures = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureService = ref.read(featureServiceProvider);
    
    final isEnabled = requireAllFeatures
        ? featureService.isEnabled(featureName)
        : features.any((f) => featureService.isEnabled(f));

    if (!isEnabled) return const SizedBox.shrink();

    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// Provider for the feature service
final featureServiceProvider = Provider<FeatureService>((ref) {
  final service = FeatureService();
  return service;
});

/// Future provider for loading features
final featuresLoadProvider = FutureProvider<void>((ref) async {
  final service = ref.read(featureServiceProvider);
  await service.init();
});
