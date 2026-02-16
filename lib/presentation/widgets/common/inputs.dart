import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';

/// Text Input Field Component
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? initialValue;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final int minLines;
  final int? maxLength;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final bool showCounter;
  final TextCapitalization textCapitalization;
  final String? prefixText;
  final Color? filledColor;

  const AppTextField({
    this.prefixText,
    this.filledColor,
    Key? key,
    required this.label,
    this.hint,
    this.initialValue,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.minLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.showCounter = false,
    this.textCapitalization = TextCapitalization.none,
  }) : super(key: key);

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.label,
          style: CoopvestTypography.labelLarge.copyWith(
            color: widget.enabled
                ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : CoopvestColors.darkGray)
                : CoopvestColors.mediumGray,
          ),
        ),
        const SizedBox(height: 8),
        // Input Field
        TextFormField(
          controller: widget.controller,
          initialValue: widget.initialValue,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          maxLines: _obscureText ? 1 : widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          obscureText: _obscureText,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          textCapitalization: widget.textCapitalization,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          style: CoopvestTypography.bodyMedium.copyWith(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : CoopvestColors.darkGray,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: CoopvestTypography.bodyMedium.copyWith(
              color: CoopvestColors.mediumGray,
            ),
            prefixIcon: widget.prefixIcon,
            prefixText: widget.prefixText,
            suffixIcon: widget.obscureText
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                    child: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: CoopvestColors.mediumGray,
                    ),
                  )
                : widget.suffixIcon,
            counterText: widget.showCounter ? null : '',
            filled: true,
            fillColor: widget.filledColor ?? (widget.enabled
                ? (Theme.of(context).brightness == Brightness.dark ? CoopvestColors.darkSurface : CoopvestColors.veryLightGray)
                : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : CoopvestColors.lightGray)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? CoopvestColors.darkDivider : CoopvestColors.lightGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? CoopvestColors.darkDivider : CoopvestColors.lightGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: CoopvestColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: CoopvestColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: CoopvestColors.error,
                width: 2,
              ),
            ),
            errorText: widget.errorText,
            errorStyle: CoopvestTypography.bodySmall.copyWith(
              color: CoopvestColors.error,
            ),
          ),
        ),
      ],
    );
  }
}

/// Dropdown Field Component
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final String? hint;
  final bool enabled;
  final Widget? prefixIcon;

  const AppDropdown({
    Key? key,
    required this.label,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.hint,
    this.enabled = true,
    this.prefixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: CoopvestTypography.labelLarge.copyWith(
            color: enabled 
                ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : CoopvestColors.darkGray) 
                : CoopvestColors.mediumGray,
          ),
        ),
        const SizedBox(height: 8),
        // Dropdown
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          dropdownColor: Theme.of(context).brightness == Brightness.dark ? CoopvestColors.darkSurface : Colors.white,
          style: CoopvestTypography.bodyMedium.copyWith(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : CoopvestColors.darkGray,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: enabled
                ? (Theme.of(context).brightness == Brightness.dark ? CoopvestColors.darkSurface : CoopvestColors.veryLightGray)
                : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : CoopvestColors.lightGray),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? CoopvestColors.darkDivider : CoopvestColors.lightGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? CoopvestColors.darkDivider : CoopvestColors.lightGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: CoopvestColors.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Checkbox Component
class AppCheckbox extends StatelessWidget {
  final bool value;
  final void Function(bool?)? onChanged;
  final String label;
  final bool enabled;

  const AppCheckbox({
    Key? key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => onChanged?.call(!value) : null,
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: CoopvestColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: CoopvestTypography.bodyMedium.copyWith(
                color: enabled
                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : CoopvestColors.darkGray)
                    : CoopvestColors.mediumGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Radio Button Component
class AppRadio<T> extends StatelessWidget {
  final T value;
  final T? groupValue;
  final void Function(T?)? onChanged;
  final String label;
  final bool enabled;

  const AppRadio({
    Key? key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => onChanged?.call(value) : null,
      child: Row(
        children: [
          // ignore: deprecated_member_use
          Radio<T>(
            value: value,
            // ignore: deprecated_member_use
            groupValue: groupValue,
            // ignore: deprecated_member_use
            onChanged: enabled ? onChanged : null,
            activeColor: CoopvestColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: CoopvestTypography.bodyMedium.copyWith(
                color: enabled
                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : CoopvestColors.darkGray)
                    : CoopvestColors.mediumGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Amount Input Field Component
class AmountInputField extends StatelessWidget {
  final String label;
  final double? initialValue;
  final TextEditingController? controller;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final double minAmount;
  final double maxAmount;

  const AmountInputField({
    Key? key,
    required this.label,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.validator,
    this.minAmount = 0,
    this.maxAmount = double.infinity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      hint: '₦0.00',
      initialValue: initialValue?.toStringAsFixed(2),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixIcon: const Padding(
        padding: EdgeInsets.only(left: 12),
        child: Text(
          '₦',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CoopvestColors.primary,
          ),
        ),
      ),
      onChanged: onChanged,
      validator: validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Amount is required';
            }
            final amount = double.tryParse(value);
            if (amount == null) {
              return 'Please enter a valid amount';
            }
            if (amount < minAmount) {
              return 'Minimum amount is ₦${minAmount.toStringAsFixed(2)}';
            }
            if (amount > maxAmount) {
              return 'Maximum amount is ₦${maxAmount.toStringAsFixed(2)}';
            }
            return null;
          },
    );
  }
}
