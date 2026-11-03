import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_evaluation.dart';
import 'package:questra/features/quest/quest_evaluation_service.dart';
import 'package:questra/features/quest/quest_model.dart';

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

  test('preserves a one-Mission AI evaluation', () {
    final evaluation = QuestEvaluation.fromJson({
      'difficulty_score': 2,
      'estimated_duration_days': 1,
      'estimated_mission_count': 1,
      'evaluated_at': '2026-11-01T00:00:00Z',
    });

    expect(evaluation?.estimatedMissionCount, 1);
  });

  test('local evaluation does not invent extra Missions', () {
    final quest = Quest(
      title: '近所の展示を見に行く',
      description: '今週末に一人で行く',
      difficulty: QuestDifficulty.easy,
      status: QuestStatus.draft,
      visibility: QuestVisibility.private,
    );

    final evaluation = QuestEvaluationService.fallback(
      quest: quest,
      missionCount: 1,
      missionDurationDays: [1],
    );

    expect(evaluation.estimatedMissionCount, 1);
  });
}
