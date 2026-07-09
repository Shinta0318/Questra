import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/arc/arc_daily_greeting_service.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/widgets/arc/arc_emotion.dart';

void main() {
  const service = ArcDailyGreetingService();
  final now = DateTime(2026, 6, 20, 9);

  test('welcomes first-time users with a first Quest prompt', () {
    final greeting = service.resolve(
      quests: const [],
      missions: const [],
      trails: const [],
      now: now,
    );

    expect(greeting.contextLabel, '冒険の最初の航路');
    expect(greeting.message, contains('最初のQuest'));
    expect(greeting.emotion, ArcEmotion.excited);
  });

  test('uses Arc name and Quest interest in first greeting', () {
    final greeting = service.resolve(
      quests: const [],
      missions: const [],
      trails: const [],
      now: now,
      nickname: 'Shinta',
      arcName: 'アーク',
      questInterest: QuestInterest.learning,
    );

    expect(greeting.contextLabel, '学習の最初の航路');
    expect(greeting.message, contains('Shinta'));
    expect(greeting.message, contains('アーク'));
    expect(greeting.message, contains('学習'));
  });

  test('prioritizes a recent Trail over active work', () {
    final trail = Trail(
      title: '朝の記録',
      summary: '一歩進んだ',
      content: '次につながる気づき',
      trailType: TrailType.manualNote,
      createdAt: now.subtract(const Duration(hours: 3)),
    );

    final greeting = service.resolve(
      quests: [_quest()],
      missions: [_mission(createdAt: now)],
      trails: [trail],
      now: now,
      nickname: 'Shinta',
    );

    expect(greeting.message, contains('Shinta'));
    expect(greeting.message, contains('朝の記録'));
    expect(greeting.emotion, ArcEmotion.celebrate);
  });

  test('warns gently when an open Mission is stale', () {
    final greeting = service.resolve(
      quests: [_quest()],
      missions: [_mission(createdAt: now.subtract(const Duration(days: 4)))],
      trails: const [],
      now: now,
    );

    expect(greeting.contextLabel, '見直しのMission');
    expect(greeting.message, contains('半分の大きさ'));
    expect(greeting.emotion, ArcEmotion.worried);
  });

  test('falls back to active Quest progress', () {
    final greeting = service.resolve(
      quests: [_quest(progress: 0.42)],
      missions: const [],
      trails: const [],
      now: now,
    );

    expect(greeting.contextLabel, '進行中のQuest');
    expect(greeting.message, contains('42%'));
    expect(greeting.emotion, ArcEmotion.normal);
  });
}

Quest _quest({double progress = 0.2}) {
  return Quest(
    title: 'Questraをローンチする',
    description: 'Betaへ進める',
    difficulty: QuestDifficulty.normal,
    status: QuestStatus.active,
    visibility: QuestVisibility.private,
    progress: progress,
  );
}

Mission _mission({required DateTime createdAt}) {
  return Mission(
    questId: 'quest-1',
    questTitle: 'Questraをローンチする',
    title: '今日の一歩',
    description: '小さく進める',
    guideType: GuideType.training,
    difficulty: MissionDifficulty.easy,
    status: MissionStatus.todo,
    createdAt: createdAt,
  );
}
