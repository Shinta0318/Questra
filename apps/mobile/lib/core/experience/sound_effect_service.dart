import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'experience_settings.dart';

final soundEffectServiceProvider = Provider<SoundEffectService>((ref) {
  return SafeSoundEffectService();
});

enum QuestraSoundEffect {
  buttonTap,
  swipe,
  missionComplete,
  questComplete,
  arcTap,
  warning,
  error,
}

abstract interface class SoundEffectService {
  Future<void> play(
    QuestraSoundEffect effect, {
    required ExperienceSettings settings,
  });
}

class SafeSoundEffectService implements SoundEffectService {
  final Map<QuestraSoundEffect, DateTime> _lastPlayed = {};

  @override
  Future<void> play(
    QuestraSoundEffect effect, {
    required ExperienceSettings settings,
  }) async {
    if (!settings.soundEffectsEnabled) return;
    final now = DateTime.now();
    final previous = _lastPlayed[effect];
    if (previous != null && now.difference(previous).inMilliseconds < 500) {
      return;
    }
    _lastPlayed[effect] = now;

    // No approved sound assets are bundled yet. This boundary intentionally
    // remains silent and lets a future audio renderer honor device silent mode.
  }
}
