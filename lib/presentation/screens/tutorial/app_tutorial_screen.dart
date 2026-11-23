import 'package:flutter/material.dart';

import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';

/// One page of the in-app tutorial.
///
/// Kept as plain data so the copy can be tested without pumping widgets — a
/// walkthrough that names a tab which does not exist, or describes an action
/// the app cannot do, teaches the member something false.
class TutorialStep {
  final String title;
  final String body;

  /// The tab this step is about, shown as a small label so the member can
  /// connect the description to a real place in the app.
  final String location;

  final IconData icon;

  const TutorialStep({
    required this.title,
    required this.body,
    required this.location,
    required this.icon,
  });
}

/// The walkthrough shown once after a member first reaches the dashboard, and
/// re-runnable from Profile at any time.
///
/// WHY THIS SHAPE
/// --------------
/// It is deliberately a *screen*, not a coach-mark overlay pinned to the live
/// dashboard. Coach marks need the real widgets on screen to anchor to, so they
/// break whenever a card is renamed or hidden (for example "Make Contribution"
/// becomes "View Contributions" for salary-deduction members). A self-contained
/// walkthrough cannot drift out of sync with the layout, works on any screen
/// size, and — most importantly — can be reopened from Profile, which an
/// overlay shown once on first launch cannot.
///
/// It is also fully dismissible. Every page has Skip, and the last page has a
/// single "Get started" action, so a member is never trapped.
class AppTutorialScreen extends StatefulWidget {
  /// Called when the member finishes or skips. The caller records completion
  /// and pops; the screen itself does not touch storage, so it stays testable
  /// and has one obvious side effect at one place.
  final VoidCallback onDone;

  const AppTutorialScreen({
    Key? key,
    required this.onDone,
  }) : super(key: key);

  /// The tutorial content, in order.
  ///
  /// Every claim here maps to something the app actually does. Update this list
  /// when a tab or primary action changes — a stale walkthrough is worse than
  /// none, because the member looks for a button that is not there.
  static const List<TutorialStep> steps = [
    TutorialStep(
      title: 'Your dashboard',
      body: 'Home shows your wallet balance, total savings and any active loan '
          'at a glance. Tap any card to open it. If you would rather not show '
          'the figures in public, use the eye icon to hide them.',
      location: 'Home',
      icon: Icons.home_outlined,
    ),
    TutorialStep(
      title: 'Save every month',
      body: 'Your monthly contribution builds your savings. The Savings card on '
          'Home opens your contribution history and shows what is still due '
          'this month. The Obligations card just below it tells you what needs '
          'paying and lets you pay it without hunting through menus.',
      location: 'Home',
      icon: Icons.savings_outlined,
    ),
    TutorialStep(
      title: 'Move money in and out',
      body: 'Wallet is where you deposit and withdraw. You can also set a '
          'savings goal for something specific, like rent or school fees, and '
          'track how close you are. Your full transaction history lives here '
          'too.',
      location: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
    ),
    TutorialStep(
      title: 'Apply for a loan',
      body: 'Loans shows what you qualify for and the repayment schedule. Some '
          'loans need a guarantor — you can share a QR code for them to scan, '
          'and track their response. If you already have a loan, you can pay '
          'it off early or roll it over from here.',
      location: 'Loans',
      icon: Icons.description_outlined,
    ),
    TutorialStep(
      title: 'Complete your KYC',
      body: 'Profile is where you finish verifying your identity and bank '
          'details. KYC unlocks the full range of services, so complete it '
          'early — it only takes a few minutes and you only do it once.',
      location: 'Profile',
      icon: Icons.badge_outlined,
    ),
    TutorialStep(
      title: 'Everything else lives in Profile',
      body: 'From Profile you can download statements, manage bank accounts, '
          'change your contribution plan, invite friends through referrals, and '
          'reach support if something is wrong. You can replay this tutorial '
          'from Profile whenever you like.',
      location: 'Profile',
      icon: Icons.person_outline,
    ),
  ];

  @override
  State<AppTutorialScreen> createState() => _AppTutorialScreenState();
}

class _AppTutorialScreenState extends State<AppTutorialScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == AppTutorialScreen.steps.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    const steps = AppTutorialScreen.steps;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Skip stays visible on every page except the last, where the
            // primary action is itself the exit. Keeping it in a fixed header
            // means the member never has to reach the end to get out.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CoopvestShape.gapLg,
                CoopvestShape.gapSm,
                CoopvestShape.gapSm,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tutorial',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.textSecondary,
                    ),
                  ),
                  if (!_isLast)
                    TextButton(
                      onPressed: widget.onDone,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          CoopvestShape.minTouchTarget,
                          CoopvestShape.minTouchTarget,
                        ),
                        foregroundColor: CoopvestColors.primary,
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    const SizedBox(height: CoopvestShape.minTouchTarget),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _TutorialPage(step: steps[i]),
              ),
            ),
            _ProgressDots(count: steps.length, index: _index),
            Padding(
              padding: const EdgeInsets.all(CoopvestShape.gapLg),
              child: Row(
                children: [
                  if (_index > 0)
                    // Back is secondary: outline only, so the emerald primary
                    // action stays the single obvious next step.
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _back,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: CoopvestColors.primary,
                          side: const BorderSide(
                            color: CoopvestColors.primary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              CoopvestShape.buttonRadius,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (_index > 0) const SizedBox(width: CoopvestShape.gapMd),
                  Expanded(
                    flex: _index > 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: CoopvestColors.primary,
                        foregroundColor: CoopvestColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            CoopvestShape.buttonRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        _isLast ? 'Get started' : 'Next',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  final TutorialStep step;

  const _TutorialPage({required this.step});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Scrollable so the body never clips at large text sizes or on short
      // screens — the icon and title alone can fill a small viewport.
      padding: const EdgeInsets.symmetric(
        horizontal: CoopvestShape.gapXl,
        vertical: CoopvestShape.gapLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: CoopvestColors.iconTintGreen,
              borderRadius: BorderRadius.circular(CoopvestShape.cardRadius),
            ),
            child: Icon(step.icon, size: 36, color: CoopvestColors.primary),
          ),
          const SizedBox(height: CoopvestShape.gapXl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CoopvestShape.gapSm + 2,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: CoopvestColors.iconTintGold,
              borderRadius: BorderRadius.circular(CoopvestShape.chipRadius),
            ),
            child: Text(
              step.location,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                // accentIcon, not accent: gold is 1.8:1 on white and unreadable
                // as text. This is the deepened gold that passes AA.
                color: CoopvestColors.accentIcon,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: CoopvestShape.gapMd),
          Text(
            step.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: CoopvestShape.gapMd),
          Text(
            step.body,
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page indicator: the active dot widens into a pill.
///
/// Shape as well as colour marks the current page, so the state does not depend
/// on distinguishing two greens.
class _ProgressDots extends StatelessWidget {
  final int count;
  final int index;

  const _ProgressDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: active ? CoopvestColors.primary : context.dividerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
