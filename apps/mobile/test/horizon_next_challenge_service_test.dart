import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/navigator_rank_service.dart';
import 'package:questra/features/challenge_graph/challenge_graph_preview_service.dart';
import 'package:questra/features/horizon/horizon_next_challenge_service.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  const service = HorizonNextChallengeService();

  test('routes users without a Quest to Arc without inventing a Quest', () {
    final suggestion = service.suggest(
      rank: _rank(NavigatorRank.novice),
      quests: const [],
      missions: const [],
      trails: const [],
    );

    expect(suggestion.readinessLabel, 'はじめの一歩');
    expect(suggestion.title, 'Arcと最初のQuestを見つける');
    expect(suggestion.destination, HorizonDestination.arc);
  });

  test('active Quest without a pending Mission routes back to Arc', () {
    final quest = _quest(status: QuestStatus.active, progress: 0.5);
    final suggestion = service.suggest(
      rank: _rank(NavigatorRank.stargazer),
      quests: [quest],
      missions: [
        _mission(quest, MissionStatus.completed),
        _mission(quest, MissionStatus.completed),
        _mission(quest, MissionStatus.completed),
      ],
      trails: [
        Trail(
          questId: quest.id,
          title: '振り返り',
          summary: '学び',
          content: '次のテーマが見えた',
          trailType: TrailType.arcReflection,
        ),
      ],
    );

    expect(suggestion.readinessLabel, '航路を準備');
    expect(suggestion.destination, HorizonDestination.arc);
  });

  test('active Quest exposes its real next Mission', () {
    final quest = _quest(status: QuestStatus.active, progress: 0.2);
    final mission = _mission(quest, MissionStatus.todo);
    final suggestion = service.suggest(
      rank: _rank(NavigatorRank.novice),
      quests: [quest],
      missions: [mission],
      trails: const [],
    );

    expect(suggestion.title, mission.title);
    expect(suggestion.readinessLabel, '次のMission');
    expect(suggestion.destination, HorizonDestination.mission);
    expect(suggestion.questId, quest.id);
    expect(suggestion.missionId, mission.id);
  });

  test('suggests larger challenge after completed Quest', () {
    final quest = _quest(status: QuestStatus.completed, progress: 1);
    final suggestion = service.suggest(
      rank: _rank(NavigatorRank.navigator),
      quests: [quest],
      missions: const [],
      trails: const [],
    );

    expect(suggestion.readinessLabel, '次のQuest候補');
    expect(suggestion.title, contains(quest.category));
  });

  test('uses Challenge Graph insight before suggesting a new Horizon', () {
    final quest = _quest(status: QuestStatus.active, progress: 0.4);
    final suggestion = service.suggest(
      rank: _rank(NavigatorRank.stargazer),
      quests: [quest],
      missions: const [],
      trails: const [],
      graphInsights: const [
        ChallengeGraphInsight(
          type: ChallengeGraphInsightType.missionGap,
          title: 'Missionの星を足す',
          message: 'このQuestには、まだ具体的な一歩が結ばれていません。',
          suggestedAction: 'Arc Guideから最初のMissionを3つ作る',
          priority: 90,
        ),
      ],
    );

    expect(suggestion.readinessLabel, '航路の提案');
    expect(suggestion.title, 'Missionの星を足す');
    expect(suggestion.suggestedAction, contains('Mission'));
  });
}

NavigatorRankState _rank(NavigatorRank rank) {
  return NavigatorRankState(
    rank: rank,
    label: rank.name,
    description: 'rank',
    stardust: 0,
    currentThreshold: 0,
    nextThreshold: 50,
    progressToNext: 0,
  );
}

Quest _quest({required QuestStatus status, required double progress}) {
  return Quest(
    title: '英語を話せるようになる',
    description: '旅先で会話したい',
    difficulty: QuestDifficulty.normal,
    status: status,
    visibility: QuestVisibility.private,
    progress: progress,
    category: '学習',
  );
}

Mission _mission(Quest quest, MissionStatus status) {
  return Mission(
    questId: quest.id,
    questTitle: quest.title,
    title: '10分練習',
    description: '小さく進める',
    guideType: GuideType.training,
    difficulty: MissionDifficulty.easy,
    status: status,
  );
}
