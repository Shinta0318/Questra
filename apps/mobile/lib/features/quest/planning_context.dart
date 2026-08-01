class PlanningContext {
  const PlanningContext({
    this.weeklyMinutes,
    this.budgetLabel,
    this.location,
    this.experience,
    this.availableResources = const [],
    this.preferences = const [],
    this.companionType,
    this.setbackReasons = const [],
    this.approvedMissionHistorySummary,
    this.consentGranted = false,
  });

  final int? weeklyMinutes;
  final String? budgetLabel;
  final String? location;
  final String? experience;
  final List<String> availableResources;
  final List<String> preferences;
  final String? companionType;
  final List<String> setbackReasons;
  final String? approvedMissionHistorySummary;
  final bool consentGranted;

  PlanningContext copyWith({
    int? weeklyMinutes,
    String? budgetLabel,
    String? location,
    String? experience,
    List<String>? availableResources,
    List<String>? preferences,
    String? companionType,
    List<String>? setbackReasons,
    String? approvedMissionHistorySummary,
    bool? consentGranted,
  }) {
    return PlanningContext(
      weeklyMinutes: weeklyMinutes ?? this.weeklyMinutes,
      budgetLabel: budgetLabel ?? this.budgetLabel,
      location: location ?? this.location,
      experience: experience ?? this.experience,
      availableResources: availableResources ?? this.availableResources,
      preferences: preferences ?? this.preferences,
      companionType: companionType ?? this.companionType,
      setbackReasons: setbackReasons ?? this.setbackReasons,
      approvedMissionHistorySummary:
          approvedMissionHistorySummary ?? this.approvedMissionHistorySummary,
      consentGranted: consentGranted ?? this.consentGranted,
    );
  }

  factory PlanningContext.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .take(20)
              .toList(growable: false)
        : const [];
    return PlanningContext(
      weeklyMinutes: (json['weekly_minutes'] as num?)?.round(),
      budgetLabel: json['budget_label'] as String?,
      location: json['location'] as String?,
      experience: json['experience'] as String?,
      availableResources: strings(json['available_resources']),
      preferences: strings(json['preferences']),
      companionType: json['companion_type'] as String?,
      setbackReasons: strings(json['setback_reasons']),
      approvedMissionHistorySummary:
          json['approved_mission_history_summary'] as String?,
      consentGranted:
          json['planning_consent_granted'] as bool? ??
          json['consent_granted'] as bool? ??
          false,
    );
  }

  Map<String, Object?> toPlanningJson() {
    if (!consentGranted) return const {'consent_granted': false};
    return {
      'consent_granted': true,
      'weekly_minutes': weeklyMinutes,
      'budget_label': budgetLabel,
      'location': location,
      'experience': experience,
      'available_resources': availableResources,
      'preferences': preferences,
      'companion_type': companionType,
      'setback_reasons': setbackReasons,
      'approved_mission_history_summary': approvedMissionHistorySummary,
    };
  }
}
