import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SoundService — sons discrets et fonctionnels, jamais de jingle de
// récompense. Respecte toujours le réglage "Sons" de l'utilisateur (voir
// AppSettingsNotifier), désactivé = silence total, sans exception.
// ─────────────────────────────────────────────────────────────────────────────

enum AppSound {
  breathingInhale('assets/sounds/breathing_inhale.wav'),
  breathingHold('assets/sounds/breathing_hold.wav'),
  breathingExhale('assets/sounds/breathing_exhale.wav'),
  checkinConfirm('assets/sounds/checkin_confirm.wav'),
  messageReceived('assets/sounds/message_received.wav'),
  challengeComplete('assets/sounds/challenge_complete.wav'),
  badgeUnlocked('assets/sounds/badge_unlocked.wav');

  final String assetPath;
  const AppSound(this.assetPath);
}

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  Future<void> play(AppSound sound) async {
    if (!_enabled) return;
    try {
      // AssetSource attend le chemin SANS le préfixe 'assets/'
      final path = sound.assetPath.replaceFirst('assets/', '');
      await _player.stop();
      await _player.play(AssetSource(path), volume: 1.0);
    } catch (e) {
      debugPrint('🔇 SoundService: impossible de jouer ${sound.name} — $e');
      // Un son manqué ne doit jamais bloquer l'expérience utilisateur.
    }
  }

  void dispose() {
    _player.dispose();
  }
}
