import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/navigator_rank_service.dart';
import 'package:questra/features/horizon/horizon_next_challenge_service.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  const service = HorizonNextChallengeService();

  test('suggests a small Quest for low readiness users', () {
    final suggestion = service.suggest(
      rank: _rank(NavigatorRank.novice),
      quests: const [],
      missions: const [],
      trails: const [],
    );

    expect(suggestion.readinessLabel, 'Low readiness');
    expect(suggestion.title, contains('7日'));
  });

  test('suggests Trail-based challenge for medium progress users', () {
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

    expect(suggestion.readinessLabel, 'Medium readiness');
    expect(suggestion.reason, contains('記録'));
  });

  test('suggests larger challenge after completed Quest', () {
    final quest = _quest(status: QuestStatus.completed, progress: 1);
    final suggestion = service.suggest(
      rank: _rank(NavigatorRank.navigator),
      quests: [quest],
      missions: const [],
      trails: const [],
    );

    expect(suggestion.readinessLabel, 'High readiness');
    expect(suggestion.title, contains(quest.category));
  });
}

NavigatorRankState _rank(NavigatorRank rank) {
  return NavigatorRankState(
    rank: rank,
    label: rank.name,
    description: 'rank',
    score: 0,
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
