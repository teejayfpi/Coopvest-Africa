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
  
  static const int splashDurationSeconds = 30;

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
      
      // Auto-dismiss after 30 seconds
      if (_elapsedSeconds >= splashDurationSeconds) {
        _dismissSplash();
        return false;
      }
      
      // Also dismiss if app is ready
      if (widget.isReady && !_dismissed) {
        _dismissSplash();
        return false;
      }
      
      return _showSplash;
    });
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady && !_dismissed) {
      _dismissSplash();
    }
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
      ]),
      builder: (context, child) {
        final pulseScale = 1.0 + (_pulseController.value * 0.08);
        
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
              // Animated background particles
              ...List.generate(20, (index) {
                final delay = index * 0.15;
                final progress = (_particleAnimation.value + delay) % 1.0;
                return Positioned(
                  left: (index * 47) % MediaQuery.of(context).size.width,
                  top: progress * MediaQuery.of(context).size.height,
                  child: Opacity(
                    opacity: 0.3 * (1 - progress),
                    child: Container(
                      width: 4 + (index % 3) * 2,
                      height: 4 + (index % 3) * 2,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),
              
              // Main content
              Opacity(
                opacity: _fadeAnimation.value,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Logo with pulse and slight rotation
                      Transform.scale(
                        scale: _scaleAnimation.value * pulseScale,
                        child: Transform.rotate(
                          angle: _rotateAnimation.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      'CV',
                                      style: TextStyle(
                                        color: CoopvestColors.primary,
                                        fontSize: 56,
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
                      
                      const SizedBox(height: 40),
                      
                      // App Name with shimmer effect
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withOpacity(0.8),
                            Colors.white,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ).createShader(bounds),
                        child: const Text(
                          'Coopvest Africa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Tagline
                      Text(
                        'Savings • Loans • Growth',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 16,
                          letterSpacing: 3,
                        ),
                      ),
                      
                      const SizedBox(height: 60),
                      
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
                      
                      const SizedBox(height: 40),
                      
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
                      
                      const SizedBox(height: 20),
                      
                      // Loading dots animation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final delay = index * 0.2;
                          final animValue = (_pulseController.value + delay) % 1.0;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3 + animValue * 0.7),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    ],
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
