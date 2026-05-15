import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final bool isReady;
  final Widget child;

  const SplashScreen({
    Key? key,
    required this.isReady,
    required this.child,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _exitController;

  // Intro animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _textFade;
  late Animation<double> _taglineFade;
  late Animation<double> _badgeFade;

  // Exit animation
  late Animation<double> _exitFade;

  bool _splashVisible = true;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Logo: scale from 0.65 → 1.0 with easeOutBack (bouncy)
    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    // Logo fades in quickly at start
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.30, curve: Curves.easeIn),
      ),
    );

    // Brand text slides up from slight offset
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.40, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.38, 0.68, curve: Curves.easeIn),
      ),
    );

    // Tagline fades in after text
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.58, 0.85, curve: Curves.easeIn),
      ),
    );

    // Security badge fades in last
    _badgeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    // Exit: fade out the whole splash overlay
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOut),
    );

    _exitController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _splashVisible = false);
      }
    });

    _introController.forward();
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady && !oldWidget.isReady) {
      _dismiss();
    }
  }

  Future<void> _dismiss() async {
    // Wait for intro to finish if still running
    if (!_introController.isCompleted) {
      await _introController.forward();
    }
    // Brief pause so the full logo is visible
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      _exitController.forward();
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashVisible) return widget.child;

    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: Listenable.merge([_introController, _exitController]),
          builder: (context, _) {
            return FadeTransition(
              opacity: _exitFade,
              child: _SplashContent(
                logoScale: _logoScale.value,
                logoOpacity: _logoOpacity.value,
                textSlide: _textSlide.value,
                textFade: _textFade.value,
                taglineFade: _taglineFade.value,
                badgeFade: _badgeFade.value,
                isReady: widget.isReady,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SplashContent extends StatelessWidget {
  final double logoScale;
  final double logoOpacity;
  final Offset textSlide;
  final double textFade;
  final double taglineFade;
  final double badgeFade;
  final bool isReady;

  const _SplashContent({
    required this.logoScale,
    required this.logoOpacity,
    required this.textSlide,
    required this.textFade,
    required this.taglineFade,
    required this.badgeFade,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F0),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Logo image with scale + fade
            Opacity(
              opacity: logoOpacity,
              child: Transform.scale(
                scale: logoScale,
                child: Image.asset(
                  'assets/images/coopvest_logo.jpg',
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Bottom area: tagline + badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  // Tagline
                  Opacity(
                    opacity: taglineFade,
                    child: const Text(
                      'Empowering Financial Inclusion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1B3A6B),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Progress indicator while loading
                  Opacity(
                    opacity: badgeFade,
                    child: !isReady
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF2E7D32),
                              ),
                            ),
                          )
                        : const SizedBox(height: 28),
                  ),

                  const SizedBox(height: 20),

                  // Security badge
                  Opacity(
                    opacity: badgeFade,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 13,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Secure & Trusted',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
