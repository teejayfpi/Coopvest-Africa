import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/content/help_faq.dart';
import 'package:coopvest_mobile/presentation/screens/support/help_center_screen.dart';

void main() {
  Widget harness() => const MaterialApp(home: HelpCenterScreen());

  testWidgets('opens on the category list, not a wall of questions',
      (tester) async {
    await tester.pumpWidget(harness());

    expect(find.text('Browse by topic'), findsOneWidget);
    expect(find.text(HelpCategory.withdrawal.label), findsOneWidget);
    expect(find.text(HelpCategory.loan.label), findsOneWidget);
  });

  testWidgets('typing a question shows matching answers', (tester) async {
    await tester.pumpWidget(harness());

    await tester.enterText(find.byType(TextField), 'withdrawal');
    await tester.pumpAndSettle();

    // The question text of a withdrawal entry is now on screen.
    expect(find.text('How do I withdraw money from my wallet?'), findsOneWidget);
    // And the browse list is gone.
    expect(find.text('Browse by topic'), findsNothing);
  });

  testWidgets('tapping an answer opens it with a route to a human',
      (tester) async {
    await tester.pumpWidget(harness());

    await tester.enterText(find.byType(TextField), 'withdrawal');
    await tester.pumpAndSettle();

    await tester.tap(find.text('How do I withdraw money from my wallet?'));
    await tester.pumpAndSettle();

    // The answer body is shown in the sheet.
    expect(
      find.textContaining('start a withdrawal to your bank account'),
      findsOneWidget,
    );
    // And there is always a way to reach a person from here.
    expect(find.text('Still need help? Contact support'), findsOneWidget);
  });

  testWidgets('a query with no answer offers support instead of a wrong answer',
      (tester) async {
    await tester.pumpWidget(harness());

    await tester.enterText(find.byType(TextField), 'cryptocurrency staking');
    await tester.pumpAndSettle();

    expect(find.textContaining('No answer matched'), findsOneWidget);
    expect(find.text('Contact Support'), findsOneWidget);
    // Critically, no help article is offered as if it answered this.
    expect(find.textContaining('How do I withdraw'), findsNothing);
  });

  testWidgets('clearing the search returns to the category list',
      (tester) async {
    await tester.pumpWidget(harness());

    await tester.enterText(find.byType(TextField), 'withdrawal');
    await tester.pumpAndSettle();
    expect(find.text('Browse by topic'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('Browse by topic'), findsOneWidget);
  });

  testWidgets('a category tile lists that topic\'s answers, with a way back',
      (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text(HelpCategory.loan.label));
    await tester.pumpAndSettle();

    expect(find.text('Why am I not eligible for a loan yet?'), findsOneWidget);
    expect(find.text('All topics'), findsOneWidget);

    await tester.tap(find.text('All topics'));
    await tester.pumpAndSettle();

    expect(find.text('Browse by topic'), findsOneWidget);
  });

  group('layout survives hostile conditions', () {
    Future<void> pumpAt(
      WidgetTester tester, {
      required Size size,
      double textScale = 1.0,
      Brightness brightness = Brightness.light,
    }) async {
      // physicalSize is in physical pixels; dpr 1.0 makes `size` logical.
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const HelpCenterScreen(),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('small phone at 320x568', (tester) async {
      await pumpAt(tester, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      expect(find.text('Browse by topic'), findsOneWidget);
    });

    testWidgets('double text scale on a small phone', (tester) async {
      await pumpAt(tester, size: const Size(320, 568), textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark mode', (tester) async {
      await pumpAt(tester, size: const Size(390, 844), brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every category opens without overflowing', (tester) async {
      await pumpAt(tester, size: const Size(390, 844));
      for (final category in HelpCategory.values) {
        await tester.tap(find.text(category.label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${category.label} overflowed');
        await tester.tap(find.text('All topics'));
        await tester.pumpAndSettle();
      }
    });
  });
}
