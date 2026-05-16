import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shows a beautiful animated splash screen for [minDuration] before
/// handing off to [child]. The [isReady] flag signals that app bootstrap
/// is complete; the screen stays visible until BOTH [isReady] is true AND
/// [minDuration] has elapsed.
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
  // intro sequence
  late final AnimationController _introCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _badgeFade;

  // pulsing rings (looped)
  late final AnimationController _pulseCtrl;

  // gentle logo float (looped)
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatY;

  // indeterminate shimmer for loading bar (looped)
  late final AnimationController _barCtrl;

  // shimmer sweep (looped)
  late final AnimationController _shimmerCtrl;

  // exit fade — reduced to 150ms delay + 400ms fade (was 300ms + 600ms)
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitFade;

  bool _splashVisible = true;
  bool _minElapsed = false;

  /// Guard against _tryDismiss being called simultaneously from
  /// _onMinElapsed() and didUpdateWidget().
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();

    // intro 1.8 s
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
    _badgeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _introCtrl,
          curve: const Interval(0.72, 1.0, curve: Curves.easeIn)),
    );

    // pulse rings
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();

    // float
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _floatY = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // indeterminate loading bar — loops independently of minDuration so it
    // never misrepresents actual boot progress.
    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();

    // shimmer
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();

    // exit: 400ms fade (was 600ms)
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

    // min-duration timer — drives the guard, NOT a visible progress bar
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
    // Guard: only one dismiss sequence can run at a time
    if (_dismissing) return;
    _dismissing = true;

    if (!_introCtrl.isCompleted) await _introCtrl.forward();
    // Reduced settle delay: 150ms (was 300ms)
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Once the splash has fully faded out, render the child with zero overhead.
    // The child is NOT built while the splash is visible — avoids wasting
    // CPU/memory on heavy home screens during the most sensitive startup window.
    if (!_splashVisible) return widget.child;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _introCtrl,
        _pulseCtrl,
        _floatCtrl,
        _barCtrl,
        _shimmerCtrl,
        _exitCtrl,
      ]),
      builder: (context, _) => FadeTransition(
        opacity: _exitFade,
        child: _SplashContent(
          logoScale: _logoScale.value,
          logoOpacity: _logoOpacity.value,
          textSlide: _textSlide.value,
          textFade: _textFade.value,
          taglineFade: _taglineFade.value,
          badgeFade: _badgeFade.value,
          pulseValue: _pulseCtrl.value,
          floatY: _floatY.value,
          barValue: _barCtrl.value,
          shimmerValue: _shimmerCtrl.value,
          isReady: widget.isReady,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SplashContent extends StatelessWidget {
  final double logoScale;
  final double logoOpacity;
  final Offset textSlide;
  final double textFade;
  final double taglineFade;
  final double badgeFade;
  final double pulseValue;
  final double floatY;
  final double barValue;
  final double shimmerValue;
  final bool isReady;

  static const Color _navy      = Color(0xFF080F1C);
  static const Color _blue      = Color(0xFF1B3A6B);
  static const Color _midBlue   = Color(0xFF1E4A8A);
  static const Color _gold      = Color(0xFFD4AF37);
  static const Color _lightGold = Color(0xFFEDD97C);
  static const Color _green     = Color(0xFF2E7D32);

  const _SplashContent({
    required this.logoScale,
    required this.logoOpacity,
    required this.textSlide,
    required this.textFade,
    required this.taglineFade,
    required this.badgeFade,
    required this.pulseValue,
    required this.floatY,
    required this.barValue,
    required this.shimmerValue,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _navy,
      body: Stack(children: [
        // radial gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.20),
              radius: 1.4,
              colors: [_midBlue, _blue, _navy],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),

        // subtle animated diagonal lines
        CustomPaint(
          size: size,
          painter: _DiagonalLinePainter(shimmerValue),
        ),

        // pulsing sonar rings
        Center(
          child: CustomPaint(
            size: const Size(260, 260),
            painter: _PulseRingPainter(pulseValue, logoOpacity),
          ),
        ),

        // main content
        SafeArea(
          child: Column(children: [
            const Spacer(flex: 3),

            // floating logo
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

            const SizedBox(height: 38),

            // brand name
            SlideTransition(
              position: AlwaysStoppedAnimation<Offset>(textSlide),
              child: Opacity(
                opacity: textFade,
                child: Column(children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [_lightGold, _gold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'COOPVEST',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 6,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'AFRICA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white38,
                      letterSpacing: 9,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 56,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_gold, _lightGold, _gold]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            // tagline
            Opacity(
              opacity: taglineFade,
              child: const Text(
                'Empowering Financial Inclusion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white38,
                  letterSpacing: 0.8,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // indeterminate loading bar + security badge
            Opacity(
              opacity: badgeFade,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52),
                child: Column(children: [
                  // Indeterminate sweep — does NOT imply a percentage of boot
                  // progress, avoiding the misleading "fake progress" problem.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _IndeterminateBar(value: barValue),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 11,
                          color: _green.withOpacity(0.75)),
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
            ),

            const SizedBox(height: 40),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Indeterminate loading bar — a gold sweep that loops left-to-right.
// ─────────────────────────────────────────────────────────────────────────────

class _IndeterminateBar extends StatelessWidget {
  final double value; // 0.0 → 1.0 looping
  const _IndeterminateBar({required this.value});

  static const Color _gold      = Color(0xFFD4AF37);
  static const Color _lightGold = Color(0xFFEDD97C);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final total = constraints.maxWidth;
      // The sweep occupies 40% of the bar width
      const sweepFraction = 0.40;
      final sweepWidth = total * sweepFraction;
      // Travels from -sweepWidth to total (full pass), driven by [value]
      final rawLeft = value * (total + sweepWidth) - sweepWidth;
      final clampedLeft = rawLeft.clamp(0.0, total);
      final clampedRight = (rawLeft + sweepWidth).clamp(0.0, total);

      return SizedBox(
        height: 2,
        child: Stack(children: [
          // track
          Container(color: Colors.white10),
          // sweep
          Positioned(
            left: clampedLeft,
            width: clampedRight - clampedLeft,
            top: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _gold.withOpacity(0.0),
                    _lightGold,
                    _gold.withOpacity(0.0),
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

// ─────────────────────────────────────────────────────────────────────────────
// Logo badge — with asset fallback so a missing logo.png is handled gracefully
// ─────────────────────────────────────────────────────────────────────────────

class _LogoBadge extends StatelessWidget {
  final double shimmerValue;
  const _LogoBadge({required this.shimmerValue});

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      // outer glow
      Container(
        width: 124,
        height: 124,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withOpacity(0.28),
              blurRadius: 52,
              spreadRadius: 10,
            ),
            BoxShadow(
              color: const Color(0xFF1B3A6B).withOpacity(0.55),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
      // gold ring
      Container(
        width: 110,
        height: 110,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFEDD97C), Color(0xFFB8962E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: ClipOval(
            child: Container(
              color: const Color(0xFF0F2040),
              // Graceful fallback when logo.png is missing or not declared
              // in pubspec.yaml — shows gold "CV" initials instead of a
              // broken-image icon that could be mistaken for intentional design.
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const Center(
                  child: Text(
                    'CV',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
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
      // shimmer sweep
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

// ─────────────────────────────────────────────────────────────────────────────
// Custom painters
// ─────────────────────────────────────────────────────────────────────────────

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
          ..color = const Color(0xFFD4AF37).withOpacity(alpha)
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
          colors: [Colors.white.withOpacity(0.16), Colors.transparent],
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
      ..color = Colors.white.withOpacity(0.025)
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
