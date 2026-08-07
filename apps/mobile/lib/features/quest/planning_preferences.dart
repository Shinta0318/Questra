import 'planning_context.dart';
import 'weekly_availability.dart';

class PlanningPreferences {
  const PlanningPreferences({
    this.availability = const WeeklyAvailability.empty(),
    this.context = const PlanningContext(),
  });

  final WeeklyAvailability availability;
  final PlanningContext context;

  PlanningContext get contextForPlanning =>
      context.copyWith(weeklyMinutes: availability.totalMinutes);

  PlanningPreferences copyWith({
    WeeklyAvailability? availability,
    PlanningContext? context,
  }) {
    return PlanningPreferences(
      availability: availability ?? this.availability,
      context: context ?? this.context,
    );
  }

  factory PlanningPreferences.fromJson(Map<String, dynamic> json) {
    final availabilitySource = json['availability'];
    final contextSource = json['context'];
    return PlanningPreferences(
      availability: WeeklyAvailability.fromJson(
        availabilitySource is Map
            ? Map<String, dynamic>.from(availabilitySource)
            : json,
      ),
      context: PlanningContext.fromJson(
        contextSource is Map ? Map<String, dynamic>.from(contextSource) : json,
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'availability': availability.toJson(),
    'context': {
      ...context.toPlanningJson(),
      'budget_label': context.budgetLabel,
      'location': context.location,
      'experience': context.experience,
      'available_resources': context.availableResources,
      'preferences': context.preferences,
      'companion_type': context.companionType,
      'setback_reasons': context.setbackReasons,
      'approved_mission_history_summary': context.approvedMissionHistorySummary,
    },
  };

  Map<String, Object?> toRemoteJson(String userId) => {
    'user_id': userId,
    for (final day in Weekday.values)
      '${day.name}_minutes': availability.minutesFor(day),
    'planning_consent_granted': context.consentGranted,
    'budget_label': context.budgetLabel,
    'location': context.location,
    'experience': context.experience,
    'available_resources': context.availableResources,
    'preferences': context.preferences,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}
