import 'package:flutter/material.dart';

import '../../../config/theme_extension.dart';
import '../widgets/common/buttons.dart';

/// Shown when the app is asked to open a route that is not in the route table.
///
/// Without this, `Navigator.pushNamed` to an unknown name throws inside the
/// navigation machinery and the member is left staring at the screen they came
/// from (or, on a cold deep link, at a blank frame). A route name can go
/// missing in the ordinary course of shipping — a feature is retired, a link is
/// mistyped, or an old notification/deep link points at a path that was
/// renamed — and that must degrade to a friendly dead end the member can leave,
/// not a crash.
class RouteNotFoundScreen extends StatelessWidget {
  /// The route name that could not be resolved, echoed back so a support agent
  /// can see exactly which link failed.
  final String? routeName;

  const RouteNotFoundScreen({super.key, this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackground,
        elevation: 0,
        title: Text('Not available', style: TextStyle(color: context.textPrimary)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.explore_off_outlined,
                  size: 64, color: context.textSecondary),
              const SizedBox(height: 24),
              Text(
                'We could not open that screen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The link may be out of date. Go back and try again, or open the '
                'screen from the app menu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Go back',
                width: double.infinity,
                onPressed: () {
                  final navigator = Navigator.of(context);
                  if (navigator.canPop()) {
                    navigator.pop();
                  } else {
                    navigator.pushReplacementNamed('/home');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
