import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// Branded splash screen with the transparent Coopvest logo over a mint gradient.
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

class _SplashScreenState extends State<SplashScreen> {
  late final AudioPlayer _audioPlayer;

  bool _showSplash = true;
  bool _dismissed = false;
  bool _soundPlayed = false;
  int _elapsedSeconds = 0;

  static const int splashDurationSeconds = 6;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playStartupSound();
    _startSplashTimer();
  }

  Future<void> _playStartupSound() async {
    if (_soundPlayed) return;
    _soundPlayed = true;

    try {
      await _audioPlayer.play(
        AssetSource('audio/coopvest_startup.mp3'),
        volume: 0.65,
      );
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

      if (_elapsedSeconds >= splashDurationSeconds) {
        _dismissSplash();
        return false;
      }

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

    if (mounted) {
      setState(() => _showSplash = false);
    }
    await _audioPlayer.stop();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) return widget.child;

    final screenSize = MediaQuery.sizeOf(context);
    final logoSize = (screenSize.width * 0.78).clamp(220.0, 360.0).toDouble();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFC6DFC9),
            Color(0xFFA9CCB5),
            Color(0xFFB9D6C0),
          ],
          stops: [0.0, 0.52, 1.0],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Image.asset(
              'assets/images/splash-logo-transparent.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
