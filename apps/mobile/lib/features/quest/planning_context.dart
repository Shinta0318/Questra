class PlanningContext {
  const PlanningContext({
    this.weeklyMinutes,
    this.budgetLabel,
    this.location,
    this.experience,
    this.availableResources = const [],
    this.preferences = const [],
    this.consentGranted = false,
  });

  final int? weeklyMinutes;
  final String? budgetLabel;
  final String? location;
  final String? experience;
  final List<String> availableResources;
  final List<String> preferences;
  final bool consentGranted;

  PlanningContext copyWith({
    int? weeklyMinutes,
    String? budgetLabel,
    String? location,
    String? experience,
    List<String>? availableResources,
    List<String>? preferences,
    bool? consentGranted,
  }) {
    return PlanningContext(
      weeklyMinutes: weeklyMinutes ?? this.weeklyMinutes,
      budgetLabel: budgetLabel ?? this.budgetLabel,
      location: location ?? this.location,
      experience: experience ?? this.experience,
      availableResources: availableResources ?? this.availableResources,
      preferences: preferences ?? this.preferences,
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
    };
  }
}
