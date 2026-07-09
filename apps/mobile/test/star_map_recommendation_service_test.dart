import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/star_map/star_map_recommendation_service.dart';
import 'package:questra/features/trail/trail_highlight_service.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  const service = StarMapRecommendationService();

  test('recommends first Quest for empty journey', () {
    final recommendations = service.recommend(
      quests: const [],
      missions: const [],
      trails: const [],
      highlights: const [],
    );

    expect(recommendations.first.sourceType, 'empty_journey');
    expect(recommendations.first.reason, contains('Quest'));
  });

  test('recommends next Mission for active low-progress Quest', () {
    final quest = Quest(
      title: '英語を話せるようになる',
      description: '旅先で会話したい',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      progress: 0.2,
      category: '学習',
    );

    final recommendations = service.recommend(
      quests: [quest],
      missions: const [],
      trails: const [],
      highlights: const [],
    );

    expect(recommendations.first.title, contains('次のMission'));
    expect(recommendations.first.sourceType, 'active_quest_gap');
  });

  test('uses Trail highlights and completed Quest momentum', () {
    final completedQuest = Quest(
      title: '富士山に登る',
      description: '登頂した',
      difficulty: QuestDifficulty.hard,
      status: QuestStatus.completed,
      visibility: QuestVisibility.private,
      progress: 1,
      category: '挑戦',
    );
    final trail = Trail(
      questId: completedQuest.id,
      title: '登頂の振り返り',
      summary: '大きな学び',
      content: '深い記録',
      trailType: TrailType.arcReflection,
    );

    final recommendations = service.recommend(
      quests: [completedQuest],
      missions: [
        Mission(
          questId: completedQuest.id,
          questTitle: completedQuest.title,
          title: '装備を確認',
          description: '準備',
          guideType: GuideType.resource,
          difficulty: MissionDifficulty.easy,
          status: MissionStatus.completed,
        ),
      ],
      trails: [trail],
      highlights: [
        TrailHighlight(
          trailId: trail.id,
          score: 82,
          reason: 'Star Memory候補',
          isStarMemoryCandidate: true,
        ),
      ],
    );

    expect(
      recommendations.map((recommendation) => recommendation.sourceType),
      contains('trail_highlight'),
    );
    expect(
      recommendations.map((recommendation) => recommendation.sourceType),
      contains('completed_quest'),
    );
  });
}
