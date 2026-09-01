import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/presentation/widgets/common/preferred_payment_date_picker.dart';

Widget _harness({
  required int month,
  int? day,
  int? year,
  ValueChanged<int>? onMonthChanged,
  ValueChanged<int>? onDayChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PreferredPaymentDatePicker(
          selectedMonth: month,
          selectedDay: day,
          year: year,
          onMonthChanged: onMonthChanged ?? (_) {},
          onDayChanged: onDayChanged ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('PreferredPaymentDatePicker', () {
    testWidgets('shows all 31 days for January', (tester) async {
      await tester.pumpWidget(_harness(month: 1, year: 2025));
      expect(find.text('31'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('hides days 29–31 for February in a common year',
        (tester) async {
      await tester.pumpWidget(_harness(month: 2, year: 2025));
      expect(find.text('28'), findsOneWidget);
      expect(find.text('29'), findsNothing);
      expect(find.text('30'), findsNothing);
      expect(find.text('31'), findsNothing);
    });

    testWidgets('shows day 29 for February in a leap year', (tester) async {
      await tester.pumpWidget(_harness(month: 2, year: 2024));
      expect(find.text('29'), findsOneWidget);
      expect(find.text('30'), findsNothing);
    });

    testWidgets('hides day 31 for April', (tester) async {
      await tester.pumpWidget(_harness(month: 4, year: 2025));
      expect(find.text('30'), findsOneWidget);
      expect(find.text('31'), findsNothing);
    });

    testWidgets('tapping a day reports it through onDayChanged',
        (tester) async {
      int? selected;
      await tester.pumpWidget(_harness(
        month: 1,
        year: 2025,
        onDayChanged: (d) => selected = d,
      ));
      await tester.tap(find.text('31'));
      expect(selected, 31);
    });

    testWidgets('selecting a month reports it through onMonthChanged',
        (tester) async {
      int? selected;
      await tester.pumpWidget(_harness(
        month: 1,
        year: 2025,
        onMonthChanged: (m) => selected = m,
      ));
      await tester.tap(find.text('January'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('February').last);
      await tester.pumpAndSettle();
      expect(selected, 2);
    });
  });
}
