import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/challenge_graph/challenge_graph_preview_service.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  const service = ChallengeGraphPreviewService();

  test(
    'builds Quest graph nodes from Quest DNA, Mission, and Trail context',
    () {
      final quest = Quest(
        title: '英語を話せるようになる',
        description: '旅先で会話したい',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.guild,
        category: '学習',
      );
      final mission = Mission(
        questId: quest.id,
        questTitle: quest.title,
        title: '15分だけ話す練習',
        description: '短く声に出す',
        guideType: GuideType.training,
        difficulty: MissionDifficulty.easy,
        status: MissionStatus.todo,
      );
      final trail = Trail(
        questId: quest.id,
        missionId: mission.id,
        title: '練習の記録',
        summary: '続けられた',
        content: '短い会話を試した',
        trailType: TrailType.missionRecord,
      );

      final preview = service.buildForQuest(
        quest: quest,
        missions: [mission],
        trails: [trail],
      );

      expect(preview.countNodes(ChallengeGraphNodeType.quest), 1);
      expect(preview.countNodes(ChallengeGraphNodeType.theme), 1);
      expect(preview.countNodes(ChallengeGraphNodeType.interest), 1);
      expect(preview.countNodes(ChallengeGraphNodeType.mission), 1);
      expect(preview.countNodes(ChallengeGraphNodeType.trail), 1);
      expect(
        preview.edges.map((edge) => edge.relationship),
        containsAll([
          'has_theme',
          'has_interest',
          'contains_mission',
          'has_trail',
          'produces_trail',
        ]),
      );
    },
  );

  test('ignores unrelated Mission and Trail nodes', () {
    final quest = Quest(
      title: '富士山に登る',
      description: '登頂する',
      difficulty: QuestDifficulty.hard,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      category: '挑戦',
    );

    final preview = service.buildForQuest(
      quest: quest,
      missions: [
        Mission(
          questId: 'other',
          questTitle: '別Quest',
          title: '別Mission',
          description: '対象外',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
          status: MissionStatus.todo,
        ),
      ],
      trails: [
        Trail(
          questId: 'other',
          title: '別Trail',
          summary: '対象外',
          content: '対象外',
          trailType: TrailType.questRecord,
        ),
      ],
    );

    expect(preview.countNodes(ChallengeGraphNodeType.mission), 0);
    expect(preview.countNodes(ChallengeGraphNodeType.trail), 0);
    expect(preview.nodes.length, 3);
  });

  test('suggests Mission creation when graph has no Mission nodes', () {
    final quest = Quest(
      title: '家族旅行を計画する',
      description: '夏に行く',
      difficulty: QuestDifficulty.easy,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      category: '旅行',
    );

    final insights = service.insightsForQuest(
      quest: quest,
      missions: const [],
      trails: const [],
    );

    expect(insights.first.type, ChallengeGraphInsightType.missionGap);
    expect(insights.first.suggestedAction, contains('Mission'));
  });

  test('suggests Trail reflection when records have grown', () {
    final quest = Quest(
      title: '富士山に登る',
      description: '登頂する',
      difficulty: QuestDifficulty.hard,
      status: QuestStatus.active,
      visibility: QuestVisibility.guild,
      category: '挑戦',
    );
    final mission = Mission(
      questId: quest.id,
      questTitle: quest.title,
      title: '装備を確認する',
      description: '足りないものを見る',
      guideType: GuideType.resource,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.completed,
    );

    final insights = service.insightsForQuest(
      quest: quest,
      missions: [mission],
      trails: [
        Trail(
          questId: quest.id,
          title: '装備チェック',
          summary: '準備できた',
          content: '靴と雨具を確認した',
          trailType: TrailType.missionRecord,
        ),
        Trail(
          questId: quest.id,
          title: '登山計画',
          summary: 'ルートを決めた',
          content: '休憩地点を決めた',
          trailType: TrailType.questRecord,
        ),
      ],
    );

    expect(
      insights.map((insight) => insight.type),
      contains(ChallengeGraphInsightType.reflectionGap),
    );
  });
}
