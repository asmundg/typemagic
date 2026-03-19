import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sound effects for the typing game.
///
/// Plays audio from assets/sounds/ when available.
/// Gracefully no-ops if sound files are missing or sound is disabled.
class AudioService {
  final AudioPlayer _keystrokePlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  bool _enabled = true;
  double _volume = 0.5;

  bool get enabled => _enabled;
  double get volume => _volume;

  void setEnabled(bool value) => _enabled = value;

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    _keystrokePlayer.setVolume(_volume);
    _effectPlayer.setVolume(_volume);
  }

  /// Play a keystroke sound (very short, low-latency)
  Future<void> playKeystroke() async {
    if (!_enabled) return;
    try {
      await _keystrokePlayer.stop();
      await _keystrokePlayer.setVolume(_volume * 0.3); // quieter for keys
      await _keystrokePlayer
          .play(AssetSource('sounds/keystroke.mp3'));
    } catch (_) {
      // Sound file not available — silent fallback
    }
  }

  /// Play an error sound (wrong key)
  Future<void> playError() async {
    if (!_enabled) return;
    try {
      await _effectPlayer.stop();
      await _effectPlayer.setVolume(_volume * 0.5);
      await _effectPlayer.play(AssetSource('sounds/error.mp3'));
    } catch (_) {}
  }

  /// Play word completion sound
  Future<void> playWordComplete() async {
    if (!_enabled) return;
    try {
      await _effectPlayer.stop();
      await _effectPlayer.setVolume(_volume * 0.4);
      await _effectPlayer
          .play(AssetSource('sounds/word_complete.mp3'));
    } catch (_) {}
  }

  /// Play test completion sound
  Future<void> playTestComplete() async {
    if (!_enabled) return;
    try {
      await _effectPlayer.stop();
      await _effectPlayer.setVolume(_volume);
      await _effectPlayer
          .play(AssetSource('sounds/test_complete.mp3'));
    } catch (_) {}
  }

  /// Play level up celebration
  Future<void> playLevelUp() async {
    if (!_enabled) return;
    try {
      await _effectPlayer.stop();
      await _effectPlayer.setVolume(_volume);
      await _effectPlayer.play(AssetSource('sounds/level_up.mp3'));
    } catch (_) {}
  }

  /// Play achievement unlock jingle
  Future<void> playAchievement() async {
    if (!_enabled) return;
    try {
      await _effectPlayer.stop();
      await _effectPlayer.setVolume(_volume);
      await _effectPlayer
          .play(AssetSource('sounds/achievement.mp3'));
    } catch (_) {}
  }

  void dispose() {
    _keystrokePlayer.dispose();
    _effectPlayer.dispose();
  }
}

/// Global audio service provider
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});
