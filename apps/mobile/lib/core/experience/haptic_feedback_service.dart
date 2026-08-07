import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'experience_settings.dart';

final hapticFeedbackServiceProvider = Provider<HapticFeedbackService>((ref) {
  return const DeviceHapticFeedbackService();
});

enum QuestraHapticCue { selection, light, medium, success, warning, error }

abstract interface class HapticFeedbackService {
  Future<void> trigger(
    QuestraHapticCue cue, {
    required ExperienceSettings settings,
  });
}

class DeviceHapticFeedbackService implements HapticFeedbackService {
  const DeviceHapticFeedbackService();

  @override
  Future<void> trigger(
    QuestraHapticCue cue, {
    required ExperienceSettings settings,
  }) async {
    if (!settings.hapticsEnabled) return;
    try {
      await switch (cue) {
        QuestraHapticCue.selection => HapticFeedback.selectionClick(),
        QuestraHapticCue.light => HapticFeedback.lightImpact(),
        QuestraHapticCue.medium => HapticFeedback.mediumImpact(),
        QuestraHapticCue.success => HapticFeedback.mediumImpact(),
        QuestraHapticCue.warning => HapticFeedback.heavyImpact(),
        QuestraHapticCue.error => HapticFeedback.vibrate(),
      };
    } catch (_) {
      // Haptics are optional and unsupported devices must continue normally.
    }
  }
}

class NoopHapticFeedbackService implements HapticFeedbackService {
  const NoopHapticFeedbackService();

  @override
  Future<void> trigger(
    QuestraHapticCue cue, {
    required ExperienceSettings settings,
  }) async {}
}
