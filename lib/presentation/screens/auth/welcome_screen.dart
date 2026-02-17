import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../widgets/common/buttons.dart';

/// Welcome Screen
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<OnboardingSlide> slides = [
    OnboardingSlide(title: 'Welcome to Coopvest Africa', subtitle: 'Save. Borrow. Invest. Together.', description: 'Join a community of salaried workers building wealth together.', icon: Icons.people, color: CoopvestColors.primary),
    OnboardingSlide(title: 'Save Together', subtitle: 'Monthly Contributions', description: 'Build your savings with peers. Make regular contributions.', icon: Icons.savings, color: CoopvestColors.secondary),
    OnboardingSlide(title: 'Borrow Easily', subtitle: 'Peer-Backed Loans', description: 'Get loans backed by your peers. Three guarantors verify your commitment.', icon: Icons.handshake, color: CoopvestColors.tertiary),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: slides.length,
            itemBuilder: (context, index) => OnboardingSlideWidget(slide: slides[index]),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: context.cardBackground, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(slides.length, (index) => Container(width: _currentPage == index ? 32 : 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: _currentPage == index ? CoopvestColors.primary : context.dividerColor, borderRadius: BorderRadius.circular(4))))),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (_currentPage < slides.length - 1) Expanded(child: SecondaryButton(label: 'Skip', onPressed: () => Navigator.of(context).pushNamed('/login'))),
                      if (_currentPage < slides.length - 1) const SizedBox(width: 12),
                      Expanded(child: PrimaryButton(label: _currentPage == slides.length - 1 ? 'Get Started' : 'Next', onPressed: () { if (_currentPage == slides.length - 1) { Navigator.of(context).pushNamed('/login'); } else { _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); } })),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingSlide {
  final String title, subtitle, description;
  final IconData icon;
  final Color color;
  OnboardingSlide({required this.title, required this.subtitle, required this.description, required this.icon, required this.color});
}

class OnboardingSlideWidget extends StatelessWidget {
  final OnboardingSlide slide;
  const OnboardingSlideWidget({Key? key, required this.slide}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 120, height: 120, decoration: BoxDecoration(color: slide.color.withOpacity(0.1), borderRadius: BorderRadius.circular(30)), child: Center(child: Icon(slide.icon, size: 60, color: slide.color))).animate().scale(duration: 600.ms).fadeIn(),
          const SizedBox(height: 40),
          Text(slide.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 12),
          Text(slide.subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slide.color)).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 20),
          Text(slide.description, textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary, height: 1.6)).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }
}
