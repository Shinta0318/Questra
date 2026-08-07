import 'quest_evaluation.dart';
import 'quest_model.dart';

abstract final class QuestEvaluationService {
  static QuestEvaluation fallback({
    required Quest quest,
    required int missionCount,
    required Iterable<int?> missionDurationDays,
  }) {
    final text = '${quest.title} ${quest.description}';
    final complex = RegExp(r'(海外移住|起業|転職|資格|留学|登頂)').hasMatch(text);
    final count = missionCount.clamp(3, 30);
    final difficulty = complex ? 4 : (count >= 10 ? 3 : 2);
    final duration = missionDurationDays.fold<int>(
      0,
      (sum, days) => sum + (days ?? 3),
    );
    return QuestEvaluation(
      difficultyScore: difficulty,
      estimatedDurationDays: duration.clamp(1, 36500),
      estimatedMissionCount: count,
      riskSummary: complex
          ? '条件の変化に合わせた定期的な航路の見直しが必要です。'
          : '最初のMissionを小さく保つと進めやすい航路です。',
      successLikelihood: complex ? 0.62 : 0.78,
      recommendedStartDate: DateTime.now(),
      version: 'local-v1',
      confidence: 0.55,
      evaluatedAt: DateTime.now(),
      rationale: 'Questの内容とMissionの数・期間から概算しました。',
    );
  }
}
