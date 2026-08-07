import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/estimation/effort_estimate.dart';
import 'package:questra/features/quest/quest_feasibility_service.dart';

void main() {
  const estimate = EffortEstimate(
    difficultyBand: '挑戦的',
    activeEffortMinutes: 1200,
    calendarDays: 120,
    confidence: 0.6,
    rationale: 'test',
  );

  test('keeps requested month and proposes a likely month', () {
    final result = QuestFeasibilityService.assess(
      now: DateTime(2026, 7, 24),
      requestedMonth: DateTime(2026, 8),
      estimate: estimate,
    );
    expect(result.requestedMonth, DateTime(2026, 8));
    expect(result.likelyMonth, DateTime(2026, 11));
    expect(result.status, QuestFeasibility.unlikely);
  });
}
