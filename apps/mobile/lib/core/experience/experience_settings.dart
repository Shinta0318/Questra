enum ArcMotionLevel { full, reduced, off }

enum CompletionEffectLevel { full, simple, off }

enum MotionPreference { standard, reduced }

enum ExperiencePreset { full, quiet, simple }

extension ArcMotionLevelLabel on ArcMotionLevel {
  String get label => switch (this) {
        ArcMotionLevel.full => '通常',
        ArcMotionLevel.reduced => '控えめ',
        ArcMotionLevel.off => 'オフ',
      };
}

extension CompletionEffectLevelLabel on CompletionEffectLevel {
  String get label => switch (this) {
        CompletionEffectLevel.full => '通常',
        CompletionEffectLevel.simple => 'シンプル',
        CompletionEffectLevel.off => 'オフ',
      };
}

class ExperienceSettings {
  const ExperienceSettings({
    this.arcMotionLevel = ArcMotionLevel.reduced,
    this.hapticsEnabled = true,
    this.soundEffectsEnabled = false,
    this.completionEffectLevel = CompletionEffectLevel.full,
    this.motionPreference = MotionPreference.standard,
    this.swipeGesturesEnabled = true,
    this.powerSavingMode = false,
  });

  const ExperienceSettings.fullExperience()
      : arcMotionLevel = ArcMotionLevel.full,
        hapticsEnabled = true,
        soundEffectsEnabled = true,
        completionEffectLevel = CompletionEffectLevel.full,
        motionPreference = MotionPreference.standard,
        swipeGesturesEnabled = true,
        powerSavingMode = false;

  const ExperienceSettings.simpleExperience()
      : arcMotionLevel = ArcMotionLevel.off,
        hapticsEnabled = false,
        soundEffectsEnabled = false,
        completionEffectLevel = CompletionEffectLevel.simple,
        motionPreference = MotionPreference.reduced,
        swipeGesturesEnabled = false,
        powerSavingMode = false;

  final ArcMotionLevel arcMotionLevel;
  final bool hapticsEnabled;
  final bool soundEffectsEnabled;
  final CompletionEffectLevel completionEffectLevel;
  final MotionPreference motionPreference;
  final bool swipeGesturesEnabled;
  final bool powerSavingMode;

  ArcMotionLevel effectiveArcMotionLevel({required bool osReduceMotion}) {
    if (arcMotionLevel == ArcMotionLevel.off) return ArcMotionLevel.off;
    if (osReduceMotion ||
        powerSavingMode ||
        motionPreference == MotionPreference.reduced) {
      return ArcMotionLevel.reduced;
    }
    return arcMotionLevel;
  }

  bool reduceScreenMotion({required bool osReduceMotion}) {
    return osReduceMotion ||
        powerSavingMode ||
        motionPreference == MotionPreference.reduced;
  }

  ExperienceSettings copyWith({
    ArcMotionLevel? arcMotionLevel,
    bool? hapticsEnabled,
    bool? soundEffectsEnabled,
    CompletionEffectLevel? completionEffectLevel,
    MotionPreference? motionPreference,
    bool? swipeGesturesEnabled,
    bool? powerSavingMode,
  }) {
    return ExperienceSettings(
      arcMotionLevel: arcMotionLevel ?? this.arcMotionLevel,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      completionEffectLevel:
          completionEffectLevel ?? this.completionEffectLevel,
      motionPreference: motionPreference ?? this.motionPreference,
      swipeGesturesEnabled: swipeGesturesEnabled ?? this.swipeGesturesEnabled,
      powerSavingMode: powerSavingMode ?? this.powerSavingMode,
    );
  }

  Map<String, Object?> toJson() => {
        'arc_motion_level': arcMotionLevel.name,
        'haptics_enabled': hapticsEnabled,
        'sound_effects_enabled': soundEffectsEnabled,
        'completion_effect_level': completionEffectLevel.name,
        'motion_preference': motionPreference.name,
        'swipe_gestures_enabled': swipeGesturesEnabled,
        'power_saving_mode': powerSavingMode,
      };

  factory ExperienceSettings.fromJson(Map<String, dynamic> json) {
    return ExperienceSettings(
      arcMotionLevel: _enumValue(
        ArcMotionLevel.values,
        json['arc_motion_level'],
        ArcMotionLevel.reduced,
      ),
      hapticsEnabled: _boolValue(json['haptics_enabled'], true),
      soundEffectsEnabled: _boolValue(json['sound_effects_enabled'], false),
      completionEffectLevel: _enumValue(
        CompletionEffectLevel.values,
        json['completion_effect_level'],
        CompletionEffectLevel.full,
      ),
      motionPreference: _enumValue(
        MotionPreference.values,
        json['motion_preference'],
        MotionPreference.standard,
      ),
      swipeGesturesEnabled: _boolValue(
        json['swipe_gestures_enabled'],
        true,
      ),
      powerSavingMode: _boolValue(json['power_saving_mode'], false),
    );
  }

  static ExperienceSettings fromPreset(ExperiencePreset preset) {
    return switch (preset) {
      ExperiencePreset.full => const ExperienceSettings.fullExperience(),
      ExperiencePreset.quiet => const ExperienceSettings(),
      ExperiencePreset.simple => const ExperienceSettings.simpleExperience(),
    };
  }
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  return values.where((value) => value.name == raw).firstOrNull ?? fallback;
}

bool _boolValue(Object? raw, bool fallback) => raw is bool ? raw : fallback;
