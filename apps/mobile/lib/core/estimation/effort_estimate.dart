class EffortEstimate {
  const EffortEstimate({
    required this.difficultyBand,
    required this.activeEffortMinutes,
    required this.calendarDays,
    required this.confidence,
    required this.rationale,
    this.version = 'effort-v1',
  });

  final String difficultyBand;
  final int activeEffortMinutes;
  final int calendarDays;
  final double confidence;
  final String rationale;
  final String version;

  String get activeEffortLabel {
    if (activeEffortMinutes < 60) return '約$activeEffortMinutes分';
    final hours = (activeEffortMinutes / 60).ceil();
    return '約$hours時間';
  }

  String get calendarLabel => calendarDays < 30
      ? '約$calendarDays日'
      : '約${(calendarDays / 30).ceil()}か月';
}

Map<String, Object> effortEstimateToJson(EffortEstimate estimate) => {
      'difficulty_band': estimate.difficultyBand,
      'active_effort_minutes': estimate.activeEffortMinutes,
      'calendar_days': estimate.calendarDays,
      'confidence': estimate.confidence,
      'rationale': estimate.rationale,
      'version': estimate.version,
    };

EffortEstimate? effortEstimateFromJson(Object? value) {
  if (value is! Map) return null;
  final data = Map<String, dynamic>.from(value);
  final minutes = (data['active_effort_minutes'] as num?)?.round();
  final days = (data['calendar_days'] as num?)?.round();
  if (minutes == null || days == null) return null;
  return EffortEstimate(
    difficultyBand: data['difficulty_band'] as String? ?? '標準',
    activeEffortMinutes: minutes,
    calendarDays: days,
    confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
    rationale: data['rationale'] as String? ?? '',
    version: data['version'] as String? ?? 'effort-v1',
  );
}
