import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Confirms the mechanism the fee disclosure host relies on: a modal sheet can
/// be presented from `navigatorKey.currentContext` during app startup.
///
/// This is not obvious — `Navigator.of(context)` searches *ancestors*, so if
/// the navigator's own context were passed it could miss the navigator it
/// belongs to. The host presents the disclosure from exactly this context, so
/// the assumption is pinned here rather than trusted.
void main() {
  testWidgets('a sheet shows from navigatorKey.currentContext', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var shown = false;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );
    await tester.pump();

    final context = navigatorKey.currentContext;
    expect(context, isNotNull);

    // Present after the first frame, as the host does.
    await tester.runAsync(() async {
      shown = true;
    });
    unawaited(showModalBottomSheet<void>(
      context: context!,
      builder: (_) => const SizedBox(height: 100, child: Text('sheet')),
    ));
    await tester.pumpAndSettle();

    expect(shown, isTrue);
    expect(find.text('sheet'), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
  });
}

void unawaited(Future<void> f) {}
