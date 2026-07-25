import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/estimation/effort_estimation_service.dart';

void main() {
  test('quest estimate separates active effort and elapsed time', () {
    final estimate = EffortEstimationService.forQuest(
      title: 'シンガポールへ行く',
      category: '旅行',
      missionCount: 9,
    );
    expect(estimate.activeEffortMinutes, greaterThan(0));
    expect(estimate.calendarDays, greaterThan(0));
    expect(estimate.confidence, inInclusiveRange(0, 1));
    expect(estimate.rationale, isNotEmpty);
  });

  test('mission estimate remains bounded when AI output is unavailable', () {
    final estimate = EffortEstimationService.forMission(
      title: '候補を比較する',
      description: '3つの候補を比較する',
    );
    expect(estimate.activeEffortMinutes, inInclusiveRange(15, 480));
    expect(estimate.version, 'effort-v1');
  });
}
