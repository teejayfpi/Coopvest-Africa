import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/presentation/screens/tutorial/app_tutorial_screen.dart';

/// Behavioural tests for the walkthrough screen.
///
/// The tutorial covers the dashboard for a first-time member, so the things
/// worth asserting are the ways it could trap or mislead someone:
///
///   1. It must always be escapable — Skip on every page but the last, and a
///      single exit on the last.
///   2. It must actually advance and go back, not just render.
///   3. Its content must match the app's real navigation, because a step that
///      points at a tab that does not exist teaches the member something false.
void main() {
  Widget harness({required VoidCallback onDone}) {
    return MaterialApp(
      home: AppTutorialScreen(onDone: onDone),
    );
  }

  group('content matches the app it describes', () {
    test('there is more than one step to walk through', () {
      expect(AppTutorialScreen.steps.length, greaterThan(1));
    });

    test('every step is complete', () {
      for (final step in AppTutorialScreen.steps) {
        expect(step.title.trim(), isNotEmpty,
            reason: 'a step with no title renders an empty page');
        expect(step.body.trim(), isNotEmpty,
            reason: 'a step with no body teaches nothing');
        expect(step.location.trim(), isNotEmpty,
            reason: 'the location label is how the member maps it to a tab');
      }
    });

    test('the locations only name tabs the bottom nav actually has', () {
      // These are the four destinations in MainContainer. A step that claims a
      // fifth tab would send the member looking for a button that is not there.
      const realTabs = {'Home', 'Wallet', 'Loans', 'Profile'};

      for (final step in AppTutorialScreen.steps) {
        final tabs = step.location.split('·').map((s) => s.trim());
        for (final tab in tabs) {
          expect(realTabs, contains(tab),
              reason: '"$tab" is not a bottom-nav tab');
        }
      }
    });

    test('each of the four tabs is introduced at least once', () {
      final covered = AppTutorialScreen.steps
          .expand((s) => s.location.split('·'))
          .map((s) => s.trim())
          .toSet();

      for (final tab in ['Home', 'Wallet', 'Loans', 'Profile']) {
        expect(covered, contains(tab), reason: '$tab is never introduced');
      }
    });
  });

  group('escaping the tutorial', () {
    testWidgets('Skip is offered on the first page and calls onDone',
        (tester) async {
      var done = 0;
      await tester.pumpWidget(harness(onDone: () => done++));

      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(done, 1);
    });

    testWidgets('Skip is gone on the last page, replaced by Get started',
        (tester) async {
      var done = 0;
      await tester.pumpWidget(harness(onDone: () => done++));

      // Walk to the end.
      for (var i = 0; i < AppTutorialScreen.steps.length - 1; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Skip'), findsNothing,
          reason: 'two exits on the last page is ambiguous');
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('Get started on the last page calls onDone exactly once',
        (tester) async {
      var done = 0;
      await tester.pumpWidget(harness(onDone: () => done++));

      for (var i = 0; i < AppTutorialScreen.steps.length - 1; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Get started'));
      await tester.pump();

      expect(done, 1);
    });
  });

  group('moving through the steps', () {
    testWidgets('the first step is shown first', (tester) async {
      await tester.pumpWidget(harness(onDone: () {}));

      expect(find.text(AppTutorialScreen.steps.first.title), findsOneWidget);
    });

    testWidgets('Next advances to the following step', (tester) async {
      await tester.pumpWidget(harness(onDone: () {}));

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text(AppTutorialScreen.steps[1].title), findsOneWidget);
      expect(find.text(AppTutorialScreen.steps.first.title), findsNothing);
    });

    testWidgets('Back is hidden on the first page and returns from the second',
        (tester) async {
      await tester.pumpWidget(harness(onDone: () {}));

      expect(find.text('Back'), findsNothing,
          reason: 'nothing to go back to on the first page');

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text(AppTutorialScreen.steps.first.title), findsOneWidget);
    });

    testWidgets('the final Next does not advance past the last step',
        (tester) async {
      var done = 0;
      await tester.pumpWidget(harness(onDone: () => done++));

      for (var i = 0; i < AppTutorialScreen.steps.length - 1; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      // On the last page the primary action is "Get started", not "Next".
      expect(find.text('Next'), findsNothing);
      expect(find.text(AppTutorialScreen.steps.last.title), findsOneWidget);
    });
  });

  group('the system back gesture', () {
    // Regression: onDone only fires for Skip and "Get started". If the caller
    // records completion there alone, dismissing with the back button leaves
    // the flag unset and the tutorial returns on the next launch — the exact
    // nagging the flag exists to prevent. The screen must not swallow the
    // back gesture, so the caller's post-push code runs.
    testWidgets('dismissing with back pops the screen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => AppTutorialScreen(onDone: () {}),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(AppTutorialScreen.steps.first.title), findsOneWidget);

      // The back gesture, as the OS delivers it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(AppTutorialScreen.steps.first.title), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
