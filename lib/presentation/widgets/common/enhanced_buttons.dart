import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_enhanced.dart';

/// Enhanced Primary Button with gradient
class EnhancedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final bool isLoading;
  final bool isEnabled;
  final List<Color>? gradientColors;
  final Color? textColor;
  final EdgeInsets? padding;
  final double? borderRadius;
  final double? elevation;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? width;
  final double? height;
  final TextStyle? textStyle;

  const EnhancedButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.isEnabled = true,
    this.gradientColors,
    this.textColor,
    this.padding,
    this.borderRadius,
    this.elevation,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
    this.height,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradientColors ?? CoopvestColorsEnhanced.primaryGradient;

    return SizedBox(
      width: width,
      height: height ?? 56,
      child: ElevatedButton(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        style: ElevatedButton.styleFrom(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? CoopvestRadius.large),
          ),
          elevation: elevation ?? 0,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isEnabled
                ? LinearGradient(
                    colors: effectiveGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isEnabled ? null : CoopvestColors.mediumGray,
            borderRadius: BorderRadius.circular(borderRadius ?? CoopvestRadius.large),
            boxShadow: isEnabled ? CoopvestShadows.coloredPrimary : null,
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leadingIcon != null) ...[
                        Icon(leadingIcon, color: textColor ?? Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: textStyle ??
                            CoopvestTypography.labelLarge.copyWith(
                              color: textColor ?? Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 8),
                        Icon(trailingIcon, color: textColor ?? Colors.white, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Secondary Outline Button
class SecondaryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final bool isLoading;
  final bool isEnabled;
  final List<Color>? borderGradient;
  final Color? textColor;
  final EdgeInsets? padding;
  final double? borderRadius;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? width;
  final double? height;

  const SecondaryButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.isEnabled = true,
    this.borderGradient,
    this.textColor,
    this.padding,
    this.borderRadius,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = borderGradient ?? CoopvestColorsEnhanced.primaryGradient;

    return SizedBox(
      width: width,
      height: height ?? 56,
      child: ElevatedButton(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        style: ElevatedButton.styleFrom(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? CoopvestRadius.large),
          ),
          elevation: 0,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isEnabled
                ? LinearGradient(
                    colors: effectiveGradient.map((c) => c.withOpacity(0.1)).toList(),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: Border.all(
              color: isEnabled ? effectiveGradient.first.withOpacity(0.5) : CoopvestColors.mediumGray,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(borderRadius ?? CoopvestRadius.large),
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(CoopvestColors.primary),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leadingIcon != null) ...[
                        Icon(leadingIcon, color: textColor ?? CoopvestColors.primary, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: CoopvestTypography.labelLarge.copyWith(
                          color: textColor ?? CoopvestColors.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 8),
                        Icon(trailingIcon, color: textColor ?? CoopvestColors.primary, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Glass Button with blur effect
class GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;

  const GlassButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height ?? 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoopvestRadius.large),
          ),
          elevation: 0,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: GlassConfig.lightGlass(opacity: 0.1, blur: 20),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: CoopvestTypography.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Gradient Icon Button
class GradientIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final List<Color> gradientColors;
  final Color? iconColor;
  final double size;
  final double? elevation;

  const GradientIconButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    this.gradientColors = CoopvestColorsEnhanced.primaryGradient,
    this.iconColor,
    this.size = 56,
    this.elevation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size / 2),
            boxShadow: elevation != null
                ? [BoxShadow(color: gradientColors[0].withOpacity(0.4), blurRadius: elevation!)]
                : CoopvestShadows.coloredPrimary,
          ),
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
            size: size * 0.45,
          ),
        ),
      ),
    );
  }
}

/// Floating Action Button with gradient
class GradientFloatingActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final List<Color> gradientColors;
  final Color? iconColor;
  final double size;

  const GradientFloatingActionButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    this.gradientColors = CoopvestColorsEnhanced.accentGradient,
    this.iconColor,
    this.size = 56,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size / 2),
      ),
      foregroundColor: iconColor ?? Colors.white,
      child: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: CoopvestShadows.coloredPrimary,
        ),
        child: Icon(icon, size: size * 0.45),
      ),
    );
  }
}

/// Biometric Button for fingerprint authentication
class BiometricButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isBiometricAvailable;
  final bool isAuthenticated;
  final String? errorMessage;

  const BiometricButton({
    Key? key,
    required this.onPressed,
    this.isBiometricAvailable = true,
    this.isAuthenticated = false,
    this.errorMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isBiometricAvailable ? onPressed : null,
            borderRadius: BorderRadius.circular(60),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: isAuthenticated
                    ? CoopvestGradients.success
                    : LinearGradient(
                        colors: [
                          CoopvestColorsEnhanced.primaryGradientStart,
                          CoopvestColorsEnhanced.primaryGradientEnd,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(60),
                boxShadow: isAuthenticated ? CoopvestShadows.coloredPrimary : CoopvestShadows.coloredPrimary,
              ),
              child: Icon(
                isAuthenticated ? Icons.check_circle : Icons.fingerprint,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (errorMessage != null)
          Text(
            errorMessage!,
            style: CoopvestTypography.bodySmall.copyWith(
              color: CoopvestColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        if (!isBiometricAvailable && errorMessage == null)
          Text(
            'Biometric not available',
            style: CoopvestTypography.bodySmall.copyWith(
              color: CoopvestColors.mediumGray,
            ),
          ),
      ],
    );
  }
}

/// Social Login Button
class SocialLoginButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final IconData icon;
  final Color iconColor;
  final Color? buttonColor;
  final double? width;

  const SocialLoginButton({
    Key? key,
    required this.onPressed,
    required this.text,
    required this.icon,
    required this.iconColor,
    this.buttonColor,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor ?? CoopvestColors.white,
          foregroundColor: CoopvestColors.darkGray,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoopvestRadius.medium),
            side: const BorderSide(
              color: CoopvestColors.lightGray,
              width: 1,
            ),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Text(
              text,
              style: CoopvestTypography.labelLarge.copyWith(
                color: CoopvestColors.darkGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab Button for segmented controls
class TabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final List<Color>? gradientColors;
  final double? width;

  const TabButton({
    Key? key,
    required this.text,
    required this.isSelected,
    required this.onTap,
    this.gradientColors,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradientColors ?? CoopvestColorsEnhanced.primaryGradient;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: effectiveGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(CoopvestRadius.large),
          border: isSelected
              ? null
              : Border.all(
                  color: CoopvestColors.lightGray,
                  width: 1,
                ),
        ),
        child: Text(
          text,
          style: CoopvestTypography.labelLarge.copyWith(
            color: isSelected ? Colors.white : CoopvestColors.mediumGray,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
