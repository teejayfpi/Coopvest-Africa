import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../config/theme_config.dart';

/// Professional Coopvest Splash Screen with Animation and Sound
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
  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final AnimationController _particleController;
  late final AudioPlayer _audioPlayer;
  
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotateAnimation;
  late final Animation<double> _particleAnimation;
  
  bool _showSplash = true;
  bool _dismissed = false;
  bool _soundPlayed = false;
  int _elapsedSeconds = 0;
  
  /// Total time the splash screen stays visible before revealing the app.
  /// The splash always runs for this full duration so that every element
  /// (logo, app name, tagline, loader, timer and loading dots) gets rendered
  /// and animated correctly.
  static const int splashDurationSeconds = 40;

  @override
  void initState() {
    super.initState();
    
    // Initialize audio player
    _audioPlayer = AudioPlayer();
    
    // Fade controller for logo appearance
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Pulse controller for logo breathing effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Rotate controller for subtle rotation
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    // Particle controller for background particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _rotateAnimation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(
        parent: _rotateController,
        curve: Curves.easeInOut,
      ),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _particleController,
        curve: Curves.linear,
      ),
    );

    // Start all animations
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
    _rotateController.repeat(reverse: true);
    
    // Play sound and start timer
    _playStartupSound();
    _startSplashTimer();
  }

  Future<void> _playStartupSound() async {
    if (_soundPlayed) return;
    _soundPlayed = true;
    
    try {
      // Play startup jingle sound
      await _audioPlayer.play(UrlSource(
        'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
      ));
      
      // Play a second chime after 1 second
      Future.delayed(const Duration(seconds: 1), () async {
        if (_showSplash && mounted) {
          await _audioPlayer.play(UrlSource(
            'https://assets.mixkit.co/active_storage/sfx/123/123-preview.mp3',
          ));
        }
      });
      
      // Play final chord after 2 seconds
      Future.delayed(const Duration(seconds: 2), () async {
        if (_showSplash && mounted) {
          await _audioPlayer.play(UrlSource(
            'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
          ));
        }
      });
    } catch (e) {
      debugPrint('Error playing startup sound: $e');
    }
  }

  void _startSplashTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _dismissed) return false;
      
      setState(() {
        _elapsedSeconds++;
      });
      
      // The splash always runs for the full configured duration so that all of its content renders before the app is revealed.
      if (_elapsedSeconds >= splashDurationSeconds) {
        _dismissSplash();
        return false;
      }
      
      
      return _showSplash;
    });
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The splash runs for its full duration regardless of readiness so that
    // all content is displayed. isReady is only used once the timer elapses.
  }

  Future<void> _dismissSplash() async {
    if (_dismissed) return;
    _dismissed = true;

    // Wait for minimum display time, then dismiss
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      await _fadeController.reverse();
      if (mounted) {
        setState(() => _showSplash = false);
        _audioPlayer.dispose();
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _particleController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) return widget.child;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _fadeController,
        _pulseController,
        _particleController,
        _rotateController,
      ]),
      builder: (context, child) {
        final pulseScale = 1.0 + (_pulseController.value * 0.08);
        final mq = MediaQuery.of(context);
        final size = mq.size;
        final viewPadding = mq.viewPadding;
        final safeTop = viewPadding.top;
        final safeBottom = viewPadding.bottom;
        // Scale spacing down on short/narrow screens so the splash content
        // never overflows the viewport.
        final scale = size.height < 640 ? 0.82 : (size.height < 800 ? 0.9 : 1.0);
        double sp(double v) => v * scale;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                CoopvestColors.primary,
                CoopvestColors.primaryDark,
                CoopvestColors.primary.withOpacity(0.9),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Animated background particles - rising bubbles
              ...List.generate(30, (index) {
                final delay = index * 0.08;
                final progress = (_particleAnimation.value + delay) % 1.0;
                final startX = (index * 37) % size.width;
                // Slight horizontal drift
                final drift = (index % 2 == 0 ? 1 : -1) * (progress * 20);

                return Positioned(
                  left: startX + drift,
                  bottom: -20 + (progress * (size.height + 40)),
                  child: Opacity(
                    opacity: 0.4 + 0.4 * (1 - (progress * 2 - 1).abs()), // Fade in middle, dim at ends
                    child: Container(
                      width: 6 + (index % 4) * 2,
                      height: 6 + (index % 4) * 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Main content - scrollable so it never overflows on small screens
              Opacity(
                opacity: _fadeAnimation.value,
                child: SafeArea(
                  top: true,
                  bottom: true,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: size.height - safeTop - safeBottom,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Animated Logo with pulse and glow effect
                              Transform.scale(
                                scale: _scaleAnimation.value * pulseScale,
                                child: Transform.rotate(
                                  angle: _rotateAnimation.value,
                                  child: Container(
                                    width: sp(140),
                                    height: sp(140),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        // Outer glow - pulsing
                                        BoxShadow(
                                          color: Colors.white
                                              .withOpacity(0.3 * pulseScale),
                                          blurRadius: 40 * pulseScale,
                                          spreadRadius: 5 * pulseScale,
                                        ),
                                        // Inner shadow
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(32),
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              'CV',
                                              style: TextStyle(
                                                color: CoopvestColors.primary,
                                                fontSize: sp(56),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: sp(40)),

                              // App Name with shimmer animation
                              ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.6),
                                      Colors.white,
                                      Colors.white.withOpacity(0.6),
                                      Colors.white,
                                    ],
                                    stops: [
                                      0.0,
                                      (_particleAnimation.value * 0.4 + 0.3) %
                                          1.0,
                                      (_particleAnimation.value * 0.4 + 0.5) %
                                          1.0,
                                      (_particleAnimation.value * 0.4 + 0.7) %
                                          1.0,
                                      1.0,
                                    ],
                                  ).createShader(bounds);
                                },
                                child: Text(
                                  'Coopvest Africa',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: scale < 1 ? 26 : 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),

                              SizedBox(height: sp(12)),

                              // Tagline
                              Text(
                                'Savings • Loans • Growth',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 16,
                                  letterSpacing: 3,
                                ),
                              ),

                              SizedBox(height: sp(60)),

                              // Animated loading indicator
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),

                              SizedBox(height: sp(40)),

                              // Timer display
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_elapsedSeconds}s / ${splashDurationSeconds}s',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: sp(20)),

                              // Loading dots animation - sequential bouncing
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(3, (index) {
                                  // Create a sequential animation where each dot bounces in turn
                                  final phaseOffset = index * 0.33;
                                  final bounceValue =
                                      (_particleController.value + phaseOffset) %
                                          1.0;
                                  // Use sine wave for smooth bounce effect
                                  final bounceHeight = (bounceValue < 0.5
                                      ? bounceValue * 2
                                      : 2 - bounceValue * 2);
                                  final opacity = 0.4 + (bounceValue * 0.6);

                                  return AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 300),
                                    margin:
                                        const EdgeInsets.symmetric(horizontal: 6),
                                    width: 10,
                                    height:
                                        10 + (bounceHeight * 6), // Bouncing height
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(opacity),
                                      borderRadius: BorderRadius.circular(5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white
                                              .withOpacity(opacity * 0.5),
                                          blurRadius: 4 + bounceHeight * 4,
                                          spreadRadius: bounceHeight * 2,
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
