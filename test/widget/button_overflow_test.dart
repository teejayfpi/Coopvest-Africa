import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/presentation/widgets/common/buttons.dart';

/// Regression coverage for the reported layout overflow: a [SecondaryButton]
/// (and its siblings) with a long label inside a width-constrained parent used
/// to paint its text past the button edge and raise a RenderFlex overflow.
///
/// The selfie capture field is the screen the bug was reported on: two buttons
/// share a Row, each in an Expanded, and "Choose from gallery" is long. A
/// 320-wide surface is the narrowest current Android phone, so if the fix
/// regresses this test fails.
void main() {
  const narrow = Size(320, 640);

  Widget harness(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  Future<void> pumpTwoUp(
    WidgetTester tester, {
    required String left,
    required String right,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: left,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SecondaryButton(
                label: right,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    ));
  }

  testWidgets('long two-up labels render without a layout overflow',
      (tester) async {
    await pumpTwoUp(tester,
        left: 'Take photo', right: 'Choose from gallery');

    expect(tester.takeException(), isNull);
    expect(find.text('Choose from gallery'), findsOneWidget);
  });

  testWidgets('survives a large accessibility text scale', (tester) async {
    await pumpTwoUp(tester,
        left: 'Take photo', right: 'Choose from gallery', textScale: 2.0);

    expect(tester.takeException(), isNull);
  });

  testWidgets('PrimaryButton and TertiaryButton handle long labels',
      (tester) async {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: 'An extremely long primary action label that will not fit',
            onPressed: () {},
          ),
          TertiaryButton(
            label: 'An extremely long tertiary action label that will not fit',
            onPressed: () {},
          ),
        ],
      ),
    ));

    expect(tester.takeException(), isNull);
  });
}
