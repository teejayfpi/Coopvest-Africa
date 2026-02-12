import 'package:flutter/material.dart';
import 'package:coopvest_mobile/config/theme_config.dart';
import 'package:coopvest_mobile/config/theme_enhanced.dart';
import 'package:coopvest_mobile/presentation/widgets/common/enhanced_buttons.dart';
import 'package:coopvest_mobile/config/animations.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CoopvestColorsEnhanced.primaryGradientStart,
              CoopvestColorsEnhanced.primaryGradientEnd,
              CoopvestColorsEnhanced.secondaryGradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: AppAnimations.scaleIn(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    child: _buildTopSection(),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _buildBottomSection(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppAnimations.pulse(
          duration: const Duration(milliseconds: 2000),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: CoopvestColorsEnhanced.primaryGradientStart.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.agriculture,
              color: Colors.white,
              size: 80,
            ),
          ),
        ),
        const SizedBox(height: 32),
        AppAnimations.fadeIn(
          duration: const Duration(milliseconds: 600),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.white, Colors.white.withOpacity(0.9)],
            ).createShader(bounds),
            child: Text(
              'CoopVest',
              style: CoopvestTypography.displayLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppAnimations.fadeIn(
          duration: const Duration(milliseconds: 800),
          child: Text(
            'Smart Savings & Investment\nfor Cooperatives',
            style: CoopvestTypography.headlineMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppAnimations.slideInUp(
          duration: const Duration(milliseconds: 600),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _buildFeatureItem(icon: Icons.security, label: 'Secure'),
                _buildFeatureItem(icon: Icons.speed, label: 'Fast'),
                _buildFeatureItem(icon: Icons.trending_up, label: 'Growth'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        AppAnimations.slideInUp(
          duration: const Duration(milliseconds: 700),
          offset: 20,
          child: EnhancedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            text: 'Get Started',
            gradientColors: CoopvestColorsEnhanced.accentGradient,
            width: double.infinity,
          ),
        ),
        const SizedBox(height: 16),
        AppAnimations.slideInUp(
          duration: const Duration(milliseconds: 800),
          offset: 30,
          child: GlassButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            text: 'Sign In',
            width: double.infinity,
          ),
        ),
        const SizedBox(height: 24),
        AppAnimations.fadeIn(
          duration: const Duration(milliseconds: 1000),
          child: Text(
            'By continuing, you agree to our Terms & Privacy Policy',
            style: CoopvestTypography.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String label}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: CoopvestTypography.labelMedium.copyWith(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
