import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<double> _overlayFade;
  bool _splashVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeIn),
      ),
    );

    _overlayFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady && !oldWidget.isReady) {
      _dismiss();
    }
  }

  Future<void> _dismiss() async {
    if (_controller.isCompleted) {
      await Future.delayed(const Duration(milliseconds: 300));
    } else {
      await _controller.forward();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (mounted) {
      setState(() => _splashVisible = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashVisible) return widget.child;

    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return FadeTransition(
              opacity: _overlayFade,
              child: _SplashContent(
                logoScale: _logoScale.value,
                textOpacity: _textFade.value,
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
  final double textOpacity;
  final bool isReady;

  const _SplashContent({
    required this.logoScale,
    required this.textOpacity,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),

            Transform.scale(
              scale: logoScale,
              child: Image.asset(
                'assets/images/splash.png',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 24),

            Opacity(
              opacity: textOpacity,
              child: Column(
                children: [
                  const Text(
                    'Coopvest Africa',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B3A6B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Empowering Financial Inclusion',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: CoopvestColors.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 3),

            Opacity(
              opacity: textOpacity,
              child: Column(
                children: [
                  if (!isReady)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          CoopvestColors.primary,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 24),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Secure & Trusted',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
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
