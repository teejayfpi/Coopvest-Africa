import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';

/// Primary Button Component
class PrimaryButton extends StatelessWidget {
  final String label;
  final FutureOr<void> Function() onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double height;
  final EdgeInsets padding;
  final TextStyle? textStyle;
  final Widget? icon;
  final MainAxisAlignment mainAxisAlignment;

  const PrimaryButton({
    required this.label,
    Key? key,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.textStyle,
    this.icon,
    this.mainAxisAlignment = MainAxisAlignment.center,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? CoopvestColors.primary
              : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : CoopvestColors.lightGray),
          foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
          disabledBackgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : CoopvestColors.lightGray,
          disabledForegroundColor: CoopvestColors.mediumGray,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: mainAxisAlignment,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: textStyle ?? CoopvestTypography.labelLarge,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Secondary Button Component
class SecondaryButton extends StatelessWidget {
  final String label;
  final FutureOr<void> Function() onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double height;
  final EdgeInsets padding;
  final TextStyle? textStyle;
  final Widget? icon;
  final MainAxisAlignment mainAxisAlignment;

  const SecondaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.textStyle,
    this.icon,
    this.mainAxisAlignment = MainAxisAlignment.center,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: CoopvestColors.primary,
          disabledForegroundColor: CoopvestColors.mediumGray,
          side: BorderSide(
            color: isEnabled
                ? CoopvestColors.primary
                : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : CoopvestColors.lightGray),
          ),
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CoopvestColors.primary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: mainAxisAlignment,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: textStyle ?? CoopvestTypography.labelLarge,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Tertiary Button Component
class TertiaryButton extends StatelessWidget {
  final String label;
  final FutureOr<void> Function() onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double height;
  final EdgeInsets padding;
  final TextStyle? textStyle;
  final Widget? icon;
  final MainAxisAlignment mainAxisAlignment;

  const TertiaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.textStyle,
    this.icon,
    this.mainAxisAlignment = MainAxisAlignment.center,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: TextButton(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        style: TextButton.styleFrom(
          foregroundColor: CoopvestColors.primary,
          disabledForegroundColor: CoopvestColors.mediumGray,
          padding: padding,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CoopvestColors.primary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: mainAxisAlignment,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: textStyle ?? CoopvestTypography.labelLarge,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Icon Button Component
class IconButtonWidget extends StatelessWidget {
  final IconData icon;
  final FutureOr<void> Function() onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final String? tooltip;

  const IconButtonWidget({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 48,
    this.iconSize = 24,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(
              icon,
              size: iconSize,
              color: color ?? CoopvestColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
