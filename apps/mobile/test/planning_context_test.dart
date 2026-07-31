import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/planning_context.dart';

void main() {
  test('planning context withholds personal conditions without consent', () {
    const context = PlanningContext(
      weeklyMinutes: 120,
      budgetLabel: '2万円まで',
      consentGranted: false,
    );
    expect(context.toPlanningJson(), const {'consent_granted': false});
  });

  test('consented context exposes only planning fields', () {
    const context = PlanningContext(
      weeklyMinutes: 120,
      budgetLabel: '2万円まで',
      experience: '初心者',
      consentGranted: true,
    );
    expect(context.toPlanningJson()['weekly_minutes'], 120);
    expect(context.toPlanningJson().containsKey('raw_chat'), isFalse);
  });
}
