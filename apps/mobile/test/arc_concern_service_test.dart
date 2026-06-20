import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_concern_service.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  const service = ArcConcernService();
  final now = DateTime(2026, 6, 20);

  test('detects overdue active Quest before other concern signals', () {
    final quest = Quest(
      title: '富士山に登る',
      description: '夏までに準備する',
      difficulty: QuestDifficulty.hard,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      targetDate: DateTime(2026, 6, 10),
    );

    final concern = service.evaluate(
      quests: [quest],
      missions: const [],
      trails: const [],
      now: now,
    );

    expect(concern?.type, ArcConcernType.overdueQuest);
    expect(concern?.message, contains('責める必要はありません'));
  });

  test('detects stale open Mission as a small-step concern', () {
    final mission = Mission(
      questId: 'quest-1',
      questTitle: '英語を話せるようになる',
      title: '会話練習をする',
      description: '10分だけ声に出す',
      guideType: GuideType.training,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
      createdAt: DateTime(2026, 6, 15),
    );

    final concern = service.evaluate(
      quests: const [],
      missions: [mission],
      trails: const [],
      now: now,
    );

    expect(concern?.type, ArcConcernType.staleMission);
    expect(concern?.questId, mission.questId);
  });

  test('detects low activity when active Quest has no recent Trail', () {
    final quest = Quest(
      title: 'Questraをローンチする',
      description: 'Betaへ進める',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    final oldTrail = Trail(
      title: '古いTrail',
      summary: 'しばらく前の記録',
      content: '前回の航路',
      trailType: TrailType.questRecord,
      createdAt: DateTime(2026, 6, 1),
    );

    final concern = service.evaluate(
      quests: [quest],
      missions: const [],
      trails: [oldTrail],
      now: now,
    );

    expect(concern?.type, ArcConcernType.lowActivity);
    expect(concern?.actionLabel, 'Trailを残す');
  });
}
