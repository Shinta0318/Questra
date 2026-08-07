import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_evaluation.dart';

void main() {
  test('normalizes persisted AI evaluation boundaries', () {
    final evaluation = QuestEvaluation.fromJson({
      'difficulty_score': 9,
      'estimated_duration_days': 0,
      'estimated_mission_count': 99,
      'estimated_success_rate': 2,
      'evaluation_version': 'test-v1',
      'evaluated_at': '2026-07-25T00:00:00Z',
    });

    expect(evaluation, isNotNull);
    expect(evaluation!.difficultyScore, 5);
    expect(evaluation.estimatedDurationDays, 1);
    expect(evaluation.estimatedMissionCount, 30);
    expect(evaluation.successLikelihood, 1);
    expect(evaluation.difficultyStars, '★★★★★');
  });
}
