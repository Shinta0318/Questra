import '../auth/auth_state.dart';
import '../mission/mission_model.dart';
import '../quest/gentle_recovery_service.dart';
import '../quest/quest_model.dart';
import 'mission_signal_model.dart';

class MissionSignalService {
  const MissionSignalService();

  List<MissionSignal> generate({
    required List<Quest> quests,
    required List<Mission> missions,
    required DateTime now,
    SignalFrequency signalFrequency = SignalFrequency.balanced,
  }) {
    final signals = <MissionSignal>[];
    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .toList(growable: false);
    final openMissions = missions
        .where((mission) => mission.status == MissionStatus.todo)
        .toList(growable: false);

    for (final quest in activeQuests) {
      final targetDate = quest.targetDate;
      if (targetDate == null) {
        continue;
      }
      final daysUntil = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      ).difference(DateTime(now.year, now.month, now.day)).inDays;
      if (daysUntil < 0) {
        signals.add(
          MissionSignal(
            type: MissionSignalType.overdueQuest,
            severity: MissionSignalSeverity.urgent,
            questId: quest.id,
            title: '期限を過ぎたQuestがあります',
            message:
                '「${quest.title}」の航路をいったん見直せます。責めずに、休む・期限を見直す・小さく戻る、どれでも大丈夫です。',
            recoveryActions: const [
              GentleRecoveryAction.pause,
              GentleRecoveryAction.reviewDeadline,
              GentleRecoveryAction.fiveMinuteStep,
            ],
            pressure: MissionSignalPressure.medium,
          ),
        );
      } else if (daysUntil <= 3) {
        signals.add(
          MissionSignal(
            type: MissionSignalType.dueSoonQuest,
            severity: MissionSignalSeverity.focus,
            questId: quest.id,
            title: 'もうすぐ期限のQuest',
            message:
                '「${quest.title}」まであと$daysUntil日。今日は一つだけ選ぶか、期限を見直しても大丈夫です。',
            recoveryActions: const [
              GentleRecoveryAction.fiveMinuteStep,
              GentleRecoveryAction.reviewDeadline,
            ],
          ),
        );
      }
    }

    for (final mission in openMissions) {
      final ageDays = now.difference(mission.createdAt).inDays;
      if (ageDays >= 3) {
        signals.add(
          MissionSignal(
            type: MissionSignalType.staleMission,
            severity: MissionSignalSeverity.focus,
            questId: mission.questId,
            missionId: mission.id,
            title: '止まっているMissionがあります',
            message: '「${mission.title}」は少し静かです。休む、5分だけ進める、小さく分ける、どれでも航路調整です。',
            recoveryActions: const [
              GentleRecoveryAction.pause,
              GentleRecoveryAction.fiveMinuteStep,
              GentleRecoveryAction.shrink,
              GentleRecoveryAction.reviewDeadline,
            ],
            pressure: MissionSignalPressure.medium,
          ),
        );
      }
    }

    if (signals.isEmpty && openMissions.isNotEmpty) {
      final mission = openMissions.first;
      signals.add(
        MissionSignal(
          type: MissionSignalType.suggestedSmallStep,
          severity: MissionSignalSeverity.calm,
          questId: mission.questId,
          missionId: mission.id,
          title: '今日の小さな一歩',
          message: '「${mission.title}」を10分だけ進める案です。無理なら今日は休んでも大丈夫です。',
          recoveryActions: const [GentleRecoveryAction.fiveMinuteStep],
        ),
      );
    }

    signals.sort((a, b) {
      final severity = _rank(b.severity).compareTo(_rank(a.severity));
      if (severity != 0) {
        return severity;
      }
      return _rankType(b.type).compareTo(_rankType(a.type));
    });
    return _applyFrequency(signals, signalFrequency);
  }

  List<MissionSignal> _applyFrequency(
    List<MissionSignal> signals,
    SignalFrequency signalFrequency,
  ) {
    final budget = pressureBudgetFor(signalFrequency);
    return switch (signalFrequency) {
      SignalFrequency.quiet =>
        signals
            .where((signal) => signal.severity != MissionSignalSeverity.calm)
            .take(budget)
            .toList(growable: false),
      SignalFrequency.balanced => signals.take(budget).toList(growable: false),
      SignalFrequency.frequent => signals.take(budget).toList(growable: false),
    };
  }

  int pressureBudgetFor(SignalFrequency signalFrequency) {
    return switch (signalFrequency) {
      SignalFrequency.quiet => 1,
      SignalFrequency.balanced => 2,
      SignalFrequency.frequent => 3,
    };
  }

  int _rank(MissionSignalSeverity severity) {
    return switch (severity) {
      MissionSignalSeverity.calm => 0,
      MissionSignalSeverity.focus => 1,
      MissionSignalSeverity.urgent => 2,
    };
  }

  int _rankType(MissionSignalType type) {
    return switch (type) {
      MissionSignalType.suggestedSmallStep => 0,
      MissionSignalType.staleMission => 1,
      MissionSignalType.dueSoonQuest => 2,
      MissionSignalType.overdueQuest => 3,
    };
  }
}
