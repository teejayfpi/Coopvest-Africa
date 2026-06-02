import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

/// Coopvest Splash Screen with brand-consistent animations
class SplashScreen extends StatefulWidget {
  final bool isReady;
  final Widget child;
  final Duration minDuration;

  const SplashScreen({
    Key? key,
    required this.isReady,
    required this.child,
    this.minDuration = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _taglineFade;

  late final AnimationController _pulseCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatY;
  late final AnimationController _barCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitFade;
  late final AnimationController _textCycleCtrl;
  
  int _currentTextIndex = 0;
  final List<String> _loadingTexts = [
    'Initializing...',
    'Loading your account...',
    'Connecting to server...',
    'Almost ready...',
  ];

  bool _splashVisible = true;
  bool _minElapsed = false;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();

    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));

    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
          parent: _introCtrl,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack)),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _introCtrl,
          curve: const Interval(0.0, 0.32, curve: Curves.easeIn)),
    );
    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.40), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _introCtrl,
          curve: const Interval(0.38, 0.72, curve: Curves.easeOutCubic)),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _introCtrl,
          curve: const Interval(0.36, 0.65, curve: Curves.easeIn)),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _introCtrl,
          curve: const Interval(0.55, 0.82, curve: Curves.easeIn)),
    );

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _floatY = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();

    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );
    _exitCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _splashVisible = false);
      }
    });

    _textCycleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..addListener(() {
        final newIndex = (_textCycleCtrl.value * _loadingTexts.length).floor();
        if (newIndex != _currentTextIndex && newIndex < _loadingTexts.length) {
          setState(() => _currentTextIndex = newIndex);
        }
      })
      ..repeat();

    Future.delayed(widget.minDuration, _onMinElapsed);
    _introCtrl.forward();
  }

  void _onMinElapsed() {
    _minElapsed = true;
    _tryDismiss();
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady && !oldWidget.isReady) {
      _tryDismiss();
    }
  }

  Future<void> _tryDismiss() async {
    if (!widget.isReady || !_minElapsed) return;
    if (_dismissing) return;
    _dismissing = true;

    if (!_introCtrl.isCompleted) await _introCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) _exitCtrl.forward();
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _barCtrl.dispose();
    _shimmerCtrl.dispose();
    _exitCtrl.dispose();
    _textCycleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashVisible) return widget.child;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _introCtrl, _pulseCtrl, _floatCtrl, _barCtrl, 
        _shimmerCtrl, _exitCtrl, _textCycleCtrl,
      ]),
      builder: (context, _) => FadeTransition(
        opacity: _exitFade,
        child: _SplashContent(
          logoScale: _logoScale.value,
          logoOpacity: _logoOpacity.value,
          textSlide: _textSlide.value,
          textFade: _textFade.value,
          taglineFade: _taglineFade.value,
          pulseValue: _pulseCtrl.value,
          floatY: _floatY.value,
          barValue: _barCtrl.value,
          shimmerValue: _shimmerCtrl.value,
          loadingText: _loadingTexts[_currentTextIndex],
        ),
      ),
    );
  }
}

class _SplashContent extends StatelessWidget {
  final double logoScale;
  final double logoOpacity;
  final Offset textSlide;
  final double textFade;
  final double taglineFade;
  final double pulseValue;
  final double floatY;
  final double barValue;
  final double shimmerValue;
  final String loadingText;

  const _SplashContent({
    required this.logoScale,
    required this.logoOpacity,
    required this.textSlide,
    required this.textFade,
    required this.taglineFade,
    required this.pulseValue,
    required this.floatY,
    required this.barValue,
    required this.shimmerValue,
    required this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: CoopvestColors.primary,
      body: Stack(children: [
        // Gradient background using Coopvest colors
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.20),
              radius: 1.4,
              colors: [
                CoopvestColors.primaryLight.withOpacity(0.8),
                CoopvestColors.primary,
                CoopvestColors.primaryDark,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),

        // Animated diagonal lines
        CustomPaint(
          size: size,
          painter: _DiagonalLinePainter(shimmerValue),
        ),

        // Pulsing rings
        Center(
          child: CustomPaint(
            size: const Size(260, 260),
            painter: _PulseRingPainter(pulseValue, logoOpacity),
          ),
        ),

        // Main content
        SafeArea(
          child: Column(children: [
            const Spacer(flex: 3),

            // Floating logo
            Transform.translate(
              offset: Offset(0, floatY * logoOpacity),
              child: Opacity(
                opacity: logoOpacity,
                child: Transform.scale(
                  scale: logoScale,
                  child: _LogoBadge(shimmerValue: shimmerValue),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // App name
            SlideTransition(
              position: AlwaysStoppedAnimation<Offset>(textSlide),
              child: Opacity(
                opacity: textFade,
                child: const Text(
                  'Coopvest Africa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Tagline
            Opacity(
              opacity: taglineFade,
              child: const Text(
                'Savings • Loans • Growth',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Loading area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 52),
              child: Column(children: [
                // Animated loading text
                SizedBox(
                  height: 18,
                  child: Text(
                    loadingText,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _IndeterminateBar(value: barValue),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_rounded,
                        size: 11, color: CoopvestColors.primaryLight.withOpacity(0.7)),
                    const SizedBox(width: 5),
                    Text(
                      'SECURE  ·  REGULATED  ·  TRUSTED',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.6,
                        color: Colors.white.withOpacity(0.30),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ]),
            ),

            const SizedBox(height: 40),
          ]),
        ),
      ]),
    );
  }
}

class _IndeterminateBar extends StatelessWidget {
  final double value;
  const _IndeterminateBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final total = constraints.maxWidth;
      const sweepFraction = 0.40;
      final sweepWidth = total * sweepFraction;
      final rawLeft = value * (total + sweepWidth) - sweepWidth;
      final clampedLeft = rawLeft.clamp(0.0, total);
      final clampedRight = (rawLeft + sweepWidth).clamp(0.0, total);

      return SizedBox(
        height: 3,
        child: Stack(children: [
          Container(color: Colors.white10),
          Positioned(
            left: clampedLeft,
            width: clampedRight - clampedLeft,
            top: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CoopvestColors.primaryLight.withOpacity(0.0),
                    CoopvestColors.primaryLight,
                    CoopvestColors.primaryLight.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

class _LogoBadge extends StatelessWidget {
  final double shimmerValue;
  const _LogoBadge({required this.shimmerValue});

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      // Outer glow
      Container(
        width: 124,
        height: 124,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: CoopvestColors.primaryLight.withOpacity(0.3),
              blurRadius: 52,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
      // Green ring
      Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              CoopvestColors.primaryLight,
              CoopvestColors.primary,
              CoopvestColors.primaryDark,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ClipOval(
            child: Container(
              color: CoopvestColors.primaryDark,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const Center(
                  child: Text(
                    'CV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      // Shimmer sweep
      ClipOval(
        child: SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(painter: _ShimmerPainter(shimmerValue)),
        ),
      ),
    ]);
  }
}

class _PulseRingPainter extends CustomPainter {
  final double t;
  final double opacity;
  const _PulseRingPainter(this.t, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.48;

    for (int i = 0; i < 3; i++) {
      final phase = ((t - i * 0.33) % 1.0).clamp(0.0, 1.0);
      final r = maxR * phase;
      final alpha = (1.0 - phase) * opacity * 0.28;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = CoopvestColors.primaryLight.withOpacity(alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) =>
      old.t != t || old.opacity != opacity;
}

class _ShimmerPainter extends CustomPainter {
  final double t;
  const _ShimmerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final angle = t * 2 * math.pi - math.pi / 2;
    final cx = size.width / 2 + math.cos(angle) * size.width * 0.55;
    final cy = size.height / 2 + math.sin(angle) * size.height * 0.55;
    canvas.drawCircle(
      Offset(cx, cy),
      58,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withOpacity(0.12), Colors.transparent],
        ).createShader(Rect.fromCircle(
            center: Offset(cx, cy), radius: 58)),
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.t != t;
}

class _DiagonalLinePainter extends CustomPainter {
  final double t;
  const _DiagonalLinePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1;
    const spacing = 52.0;
    final offset = (t * spacing) % spacing;
    for (double x = -size.height + offset;
        x < size.width + size.height;
        x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_DiagonalLinePainter old) => old.t != t;
}
