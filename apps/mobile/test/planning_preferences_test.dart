import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/planning_context.dart';
import 'package:questra/features/quest/planning_preferences.dart';
import 'package:questra/features/quest/weekly_availability.dart';

void main() {
  test('planning preferences combine explicit weekly availability', () {
    const preferences = PlanningPreferences(
      availability: WeeklyAvailability(
        minutesByDay: {Weekday.monday: 30, Weekday.saturday: 120},
      ),
      context: PlanningContext(budgetLabel: '1万円未満', consentGranted: true),
    );

    expect(preferences.contextForPlanning.weeklyMinutes, 150);
    expect(
      preferences.contextForPlanning.toPlanningJson()['budget_label'],
      '1万円未満',
    );
  });

  test('remote row round trip preserves consent and each weekday', () {
    final value = PlanningPreferences.fromJson({
      'monday_minutes': 30,
      'friday_minutes': 60,
      'planning_consent_granted': true,
      'experience': '初めて',
      'available_resources': ['パソコン'],
      'preferences': ['休日中心'],
    });

    expect(value.availability.totalMinutes, 90);
    expect(value.context.consentGranted, isTrue);
    expect(value.context.availableResources, ['パソコン']);
  });
}
