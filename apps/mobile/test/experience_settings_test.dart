import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/experience/experience_settings.dart';
import 'package:questra/core/experience/experience_settings_controller.dart';
import 'package:questra/core/experience/experience_settings_repository.dart';

void main() {
  test('quiet experience is the safe default', () {
    const settings = ExperienceSettings();

    expect(settings.arcMotionLevel, ArcMotionLevel.reduced);
    expect(settings.hapticsEnabled, isTrue);
    expect(settings.soundEffectsEnabled, isFalse);
    expect(settings.swipeGesturesEnabled, isTrue);
  });

  test('invalid persisted values fall back safely', () {
    final settings = ExperienceSettings.fromJson({
      'arc_motion_level': 'unknown',
      'haptics_enabled': 'yes',
      'completion_effect_level': 'extreme',
      'motion_preference': 10,
    });

    expect(settings.arcMotionLevel, ArcMotionLevel.reduced);
    expect(settings.hapticsEnabled, isTrue);
    expect(settings.completionEffectLevel, CompletionEffectLevel.full);
    expect(settings.motionPreference, MotionPreference.standard);
  });

  test('OS reduce motion and power saving cap Arc motion', () {
    const full = ExperienceSettings.fullExperience();

    expect(
      full.effectiveArcMotionLevel(osReduceMotion: false),
      ArcMotionLevel.full,
    );
    expect(
      full.effectiveArcMotionLevel(osReduceMotion: true),
      ArcMotionLevel.reduced,
    );
    expect(
      full.copyWith(powerSavingMode: true).effectiveArcMotionLevel(
            osReduceMotion: false,
          ),
      ArcMotionLevel.reduced,
    );
  });

  test('controller persists updates through the repository boundary', () async {
    final repository = InMemoryExperienceSettingsRepository();
    final container = ProviderContainer(
      overrides: [
        experienceSettingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      experienceSettingsControllerProvider.notifier,
    );
    await controller.applyPreset(ExperiencePreset.simple);

    expect(
      container.read(experienceSettingsControllerProvider).arcMotionLevel,
      ArcMotionLevel.off,
    );
    expect(repository.value?.swipeGesturesEnabled, isFalse);
  });
}
