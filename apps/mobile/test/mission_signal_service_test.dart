import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/signal/mission_signal_model.dart';
import 'package:questra/features/signal/mission_signal_service.dart';

void main() {
  const service = MissionSignalService();
  final now = DateTime(2026, 6, 21, 9);

  test('prioritizes overdue Quest signals', () {
    final quest = Quest(
      title: 'Questraをローンチする',
      description: 'Betaへ進める',
      difficulty: QuestDifficulty.hard,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      targetDate: DateTime(2026, 6, 20),
    );

    final signals = service.generate(
      quests: [quest],
      missions: const [],
      now: now,
    );

    expect(signals.first.type, MissionSignalType.overdueQuest);
    expect(signals.first.severity, MissionSignalSeverity.urgent);
    expect(signals.first.message, contains('責めずに'));
  });

  test('detects stale open Missions', () {
    final mission = Mission(
      questId: 'quest-1',
      questTitle: '英語を話せるようになる',
      title: '単語を10個読む',
      description: '短い練習',
      guideType: GuideType.training,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
      createdAt: DateTime(2026, 6, 17),
    );

    final signals = service.generate(
      quests: const [],
      missions: [mission],
      now: now,
    );

    expect(signals.first.type, MissionSignalType.staleMission);
    expect(signals.first.message, contains('5分'));
  });

  test('suggests a small step when there is open work without risk', () {
    final mission = Mission(
      questId: 'quest-1',
      questTitle: '富士山に登る',
      title: '装備リストを作る',
      description: '必要なものを確認する',
      guideType: GuideType.resource,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
      createdAt: DateTime(2026, 6, 21, 8),
    );

    final signals = service.generate(
      quests: const [],
      missions: [mission],
      now: now,
    );

    expect(signals.first.type, MissionSignalType.suggestedSmallStep);
    expect(signals.first.severity, MissionSignalSeverity.calm);
  });
}
