import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/gentle_recovery_service.dart';
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
    expect(signals.first.offersRest, isTrue);
    expect(
      signals.first.recoveryActions,
      contains(GentleRecoveryAction.reviewDeadline),
    );
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
    expect(signals.first.offersRest, isTrue);
    expect(signals.first.message, isNot(contains('急')));
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
    expect(signals.first.message, contains('休んでも大丈夫'));
  });

  test('quiet Signal frequency suppresses calm nudges', () {
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
      signalFrequency: SignalFrequency.quiet,
    );

    expect(signals, isEmpty);
  });

  test('Signal pressure budget caps non-coercive interventions', () {
    final quest = Quest(
      title: '海外旅行へ行く',
      description: '旅を実現する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      targetDate: DateTime(2026, 6, 20),
    );
    final missions = [
      _mission('m1', createdAt: DateTime(2026, 6, 10)),
      _mission('m2', createdAt: DateTime(2026, 6, 11)),
      _mission('m3', createdAt: DateTime(2026, 6, 12)),
    ];

    final balanced = service.generate(
      quests: [quest],
      missions: missions,
      now: now,
      signalFrequency: SignalFrequency.balanced,
    );
    final frequent = service.generate(
      quests: [quest],
      missions: missions,
      now: now,
      signalFrequency: SignalFrequency.frequent,
    );

    expect(service.pressureBudgetFor(SignalFrequency.quiet), 1);
    expect(balanced, hasLength(2));
    expect(frequent, hasLength(3));
    for (final signal in frequent) {
      expect(signal.message, isNot(contains('必ず')));
      expect(signal.message, isNot(contains('今すぐ')));
      expect(signal.message, isNot(contains('失敗')));
      expect(signal.message, isNot(contains('Arcが寂しい')));
    }
  });
}

Mission _mission(String id, {required DateTime createdAt}) => Mission(
  id: id,
  questId: 'quest-1',
  questTitle: '海外旅行へ行く',
  title: 'Mission $id',
  description: '準備する',
  guideType: GuideType.route,
  difficulty: MissionDifficulty.normal,
  status: MissionStatus.todo,
  createdAt: createdAt,
);
