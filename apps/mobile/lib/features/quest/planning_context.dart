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
