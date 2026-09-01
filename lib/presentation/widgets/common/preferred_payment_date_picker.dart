import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/payment_date_utils.dart';

/// A month + day picker for choosing a preferred payment date.
///
/// The user first picks a month, then a day from 1 up to the actual number
/// of days in that month (28/29 for February depending on leap year, 30 or
/// 31 otherwise). Days that do not exist in the selected month are never
/// shown, so an invalid date cannot be selected.
class PreferredPaymentDatePicker extends StatelessWidget {
  /// Currently selected month (1–12). Defaults to the current month.
  final int selectedMonth;

  /// Currently selected day of month, or null when nothing is selected yet.
  final int? selectedDay;

  /// Year used to resolve February's length. Defaults to the current year,
  /// which keeps the 29th available throughout a leap year.
  final int? year;

  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onDayChanged;

  const PreferredPaymentDatePicker({
    Key? key,
    required this.selectedMonth,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDayChanged,
    this.year,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveYear = year ?? DateTime.now().year;
    final validDays =
        PaymentDateUtils.validDaysForMonth(effectiveYear, selectedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.cardBackground,
            border: Border.all(color: context.dividerColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedMonth,
              isExpanded: true,
              items: List<int>.generate(12, (i) => i + 1).map((month) {
                return DropdownMenuItem<int>(
                  value: month,
                  child: Text(PaymentDateUtils.monthNames[month - 1]),
                );
              }).toList(),
              onChanged: (month) {
                if (month != null) onMonthChanged(month);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: validDays.map((day) {
            final isSelected = selectedDay == day;
            return GestureDetector(
              onTap: () => onDayChanged(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? CoopvestColors.primary
                      : context.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? CoopvestColors.primary
                        : context.dividerColor,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected ? Colors.white : context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
