import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static bool isEnabled = true;
  static bool _isInitialized = false;

  static final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier<bool>(true);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isEnabled = prefs.getBool('puff_sound_enabled') ?? true;
      soundEnabledNotifier.value = isEnabled;

      await _player.setAsset('assets/audio/puff_sound.wav');
      await _player.setVolume(1.0);
      _isInitialized = true;
    } catch (_) {}
  }

  static Future<void> toggleSound(bool value) async {
    isEnabled = value;
    soundEnabledNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('puff_sound_enabled', value);
  }

  static Future<void> playPuffSound() async {
    if (!isEnabled) return;

    try {
      HapticFeedback.mediumImpact();
      if (_isInitialized) {
        await _player.seek(Duration.zero);
        await _player.play();
      } else {
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {
      // Fallback to system audio click
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  static void dispose() {
    _player.dispose();
  }
}
