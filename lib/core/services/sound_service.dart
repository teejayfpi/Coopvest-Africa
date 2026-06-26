import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for playing notification and UI sounds
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _soundEnabled = true;
  
  // Sound URLs - using reliable CDN
  static const String _notificationSoundUrl = 
      'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';
  static const String _messageSoundUrl = 
      'https://assets.mixkit.co/active_storage/sfx/123/123-preview.mp3';
  static const String _successSoundUrl = 
      'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';
  static const String _errorSoundUrl = 
      'https://assets.mixkit.co/active_storage/sfx/2000/2000-preview.mp3';

  bool get soundEnabled => _soundEnabled;
  
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// Initialize the audio player with proper settings
  Future<void> initialize() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      await _player.setPlaybackRate(1.0);
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }

  /// Play notification received sound with haptic feedback
  Future<void> playNotificationSound() async {
    if (!_soundEnabled) return;
    
    try {
      // Haptic feedback
      await HapticFeedback.mediumImpact();
      
      // Play sound
      await _player.stop();
      await _player.setSourceUrl(_notificationSoundUrl);
      await _player.resume();
      
      debugPrint('Notification sound played');
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
      // Try alternative approach
      try {
        await _player.play(UrlSource(_notificationSoundUrl));
      } catch (e2) {
        debugPrint('Fallback also failed: $e2');
      }
    }
  }

  /// Play message received sound with haptic feedback
  Future<void> playMessageSound() async {
    if (!_soundEnabled) return;
    
    try {
      await HapticFeedback.lightImpact();
      await _player.stop();
      await _player.setSourceUrl(_messageSoundUrl);
      await _player.resume();
    } catch (e) {
      debugPrint('Error playing message sound: $e');
      try {
        await _player.play(UrlSource(_messageSoundUrl));
      } catch (e2) {
        debugPrint('Fallback also failed: $e2');
      }
    }
  }

  /// Play success/completion sound with haptic feedback
  Future<void> playSuccessSound() async {
    if (!_soundEnabled) return;
    
    try {
      await HapticFeedback.heavyImpact();
      await _player.stop();
      await _player.setSourceUrl(_successSoundUrl);
      await _player.resume();
    } catch (e) {
      debugPrint('Error playing success sound: $e');
      try {
        await _player.play(UrlSource(_successSoundUrl));
      } catch (e2) {
        debugPrint('Fallback also failed: $e2');
      }
    }
  }

  /// Play error sound with haptic feedback
  Future<void> playErrorSound() async {
    if (!_soundEnabled) return;
    
    try {
      await HapticFeedback.vibrate();
      await _player.stop();
      await _player.setSourceUrl(_errorSoundUrl);
      await _player.resume();
    } catch (e) {
      debugPrint('Error playing error sound: $e');
      try {
        await _player.play(UrlSource(_errorSoundUrl));
      } catch (e2) {
        debugPrint('Fallback also failed: $e2');
      }
    }
  }

  /// Play ticket reply sound (for admin responding to tickets)
  Future<void> playTicketReplySound() async {
    if (!_soundEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
      await _player.stop();
      await _player.setSourceUrl(_notificationSoundUrl);
      await _player.resume();
    } catch (e) {
      debugPrint('Error playing ticket reply sound: $e');
      try {
        await _player.play(UrlSource(_notificationSoundUrl));
      } catch (e2) {
        debugPrint('Fallback also failed: $e2');
      }
    }
  }

  /// Play new ticket sound (for admin when new ticket is created)
  Future<void> playNewTicketSound() async {
    if (!_soundEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await _player.stop();
      await _player.setSourceUrl(_errorSoundUrl);
      await _player.resume();
    } catch (e) {
      debugPrint('Error playing new ticket sound: $e');
      try {
        await _player.play(UrlSource(_errorSoundUrl));
      } catch (e2) {
        debugPrint('Fallback also failed: $e2');
      }
    }
  }

  /// Play deposit notification sound
  Future<void> playDepositSound() async {
    if (!_soundEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
      await _player.stop();
      await _player.setSourceUrl(_successSoundUrl);
      await _player.resume();
    } catch (e) {
      debugPrint('Error playing deposit sound: $e');
      try {
        await _player.play(UrlSource(_successSoundUrl));
      } catch (e2) {
        debugPrint('Fallback also failed: $e2');
      }
    }
  }

  /// Stop any playing sound
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Error stopping sound: $e');
    }
  }

  /// Dispose the audio player
  void dispose() {
    try {
      _player.dispose();
    } catch (e) {
      debugPrint('Error disposing audio player: $e');
    }
  }
}
