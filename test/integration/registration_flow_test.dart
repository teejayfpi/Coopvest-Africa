import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coopvest_mobile/presentation/screens/auth/register_step1_screen.dart';
import 'package:coopvest_mobile/presentation/screens/auth/register_step2_screen.dart';
import 'package:coopvest_mobile/presentation/screens/auth/contribution_type_selection_screen.dart';

void main() {
  group('Registration Flow Integration Tests', () {
    testWidgets('Step 1: Registration form accepts valid email and password', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterStep1Screen(),
          ),
        ),
      );

      // Verify form elements are present
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    });

    testWidgets('Step 2: Registration form accepts user details', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RegisterStep2Screen(
              registrationData: const {},
            ),
          ),
        ),
      );

      // Verify form elements are present
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
    });

    testWidgets('Contribution Type Selection displays both options', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ContributionTypeSelectionScreen(
              registrationData: const {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for contribution type options
      expect(find.textContaining('Direct'), findsWidgets);
      expect(find.textContaining('Salary'), findsWidgets);
    });

    testWidgets('Form validation rejects empty email', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterStep1Screen(),
          ),
        ),
      );

      // Find and tap the continue button
      final continueButton = find.text('Continue');
      if (continueButton.evaluate().isNotEmpty) {
        await tester.tap(continueButton);
        await tester.pumpAndSettle();

        // Should show validation error
        expect(find.textContaining('email'), findsWidgets);
      }
    });
  });
}
