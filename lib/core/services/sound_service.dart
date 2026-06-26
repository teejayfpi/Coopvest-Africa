import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for playing notification and UI sounds
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _soundEnabled = true;

  bool get soundEnabled => _soundEnabled;
  
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// Play notification received sound
  Future<void> playNotificationSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.stop();
      // Using a system notification sound URL
      await _player.play(UrlSource(
        'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
      ));
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
  }

  /// Play message received sound
  Future<void> playMessageSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(UrlSource(
        'https://assets.mixkit.co/active_storage/sfx/123/123-preview.mp3',
      ));
    } catch (e) {
      debugPrint('Error playing message sound: $e');
    }
  }

  /// Play success/completion sound
  Future<void> playSuccessSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(UrlSource(
        'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
      ));
    } catch (e) {
      debugPrint('Error playing success sound: $e');
    }
  }

  /// Play error sound
  Future<void> playErrorSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(UrlSource(
        'https://assets.mixkit.co/active_storage/sfx/2000/2000-preview.mp3',
      ));
    } catch (e) {
      debugPrint('Error playing error sound: $e');
    }
  }

  /// Play ticket reply sound (for admin responding to tickets)
  Future<void> playTicketReplySound() async {
    if (!_soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(UrlSource(
        'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
      ));
    } catch (e) {
      debugPrint('Error playing ticket reply sound: $e');
    }
  }

  /// Play new ticket sound (for admin when new ticket is created)
  Future<void> playNewTicketSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(UrlSource(
        'https://assets.mixkit.co/active_storage/sfx/2000/2000-preview.mp3',
      ));
    } catch (e) {
      debugPrint('Error playing new ticket sound: $e');
    }
  }

  /// Play deposit notification sound
  Future<void> playDepositSound() async {
    if (!_soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(UrlSource(
        'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
      ));
    } catch (e) {
      debugPrint('Error playing deposit sound: $e');
    }
  }

  /// Stop any playing sound
  Future<void> stop() async {
    await _player.stop();
  }

  /// Dispose the audio player
  void dispose() {
    _player.dispose();
  }
}
