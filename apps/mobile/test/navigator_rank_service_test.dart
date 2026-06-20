import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/navigator_rank_service.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  const service = NavigatorRankService();

  test('starts as novice with little journey activity', () {
    final rank = service.resolve(
      quests: const [],
      missions: const [],
      trails: const [],
      bondScore: 0,
      stardustBalance: 0,
    );

    expect(rank.rank, NavigatorRank.novice);
    expect(rank.progressToNext, 0);
  });

  test('uses Quest Mission Trail Bond and Stardust to resolve rank', () {
    final quest = Quest(
      title: 'Questraをローンチする',
      description: 'Betaへ進める',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.completed,
      visibility: QuestVisibility.private,
    );
    final mission = Mission(
      questId: quest.id,
      questTitle: quest.title,
      title: 'Mission完了',
      description: '一歩進めた',
      guideType: GuideType.training,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.completed,
    );
    final trail = Trail(
      questId: quest.id,
      missionId: mission.id,
      title: 'Reflection',
      summary: '学び',
      content: '次の一歩',
      trailType: TrailType.arcReflection,
    );

    final rank = service.resolve(
      quests: [quest],
      missions: [mission],
      trails: [trail],
      bondScore: 50,
      stardustBalance: 80,
    );

    expect(rank.score, greaterThanOrEqualTo(55));
    expect(rank.rank, NavigatorRank.stargazer);
  });

  test('maps stored rank keys', () {
    expect(service.fromStorage('navigator'), NavigatorRank.navigator);
    expect(NavigatorRank.pathfinder.storageKey, 'pathfinder');
  });
}
