import '../mission/mission_model.dart';
import '../task/task_model.dart';

enum QuestJourneyMode { focus, plan }

class QuestJourneyProgress {
  const QuestJourneyProgress({
    required this.completedMissions,
    required this.totalMissions,
    required this.weightedProgress,
  });

  final int completedMissions;
  final int totalMissions;
  final double weightedProgress;

  int get percent => (weightedProgress.clamp(0, 1) * 100).round();
  String get label => '$completedMissions / $totalMissions Mission';
}

/// Quest progress is an outcome signal. Task count is intentionally excluded
/// so that splitting one action into many Tasks cannot inflate progress.
class QuestJourneyProgressService {
  const QuestJourneyProgressService();

  QuestJourneyProgress calculate(Iterable<Mission> missions) {
    final active = missions
        .where(
          (mission) =>
              mission.isOutcomeMission &&
              mission.required &&
              mission.routeState != MissionRouteState.removed,
        )
        .toList(growable: false);
    if (active.isEmpty) {
      return const QuestJourneyProgress(
        completedMissions: 0,
        totalMissions: 0,
        weightedProgress: 0,
      );
    }
    final totalWeight = active.fold<double>(
      0,
      (sum, mission) => sum + mission.weight.clamp(0.1, 100),
    );
    final completedWeight = active
        .where((mission) => mission.status == MissionStatus.completed)
        .fold<double>(
          0,
          (sum, mission) => sum + mission.weight.clamp(0.1, 100),
        );
    return QuestJourneyProgress(
      completedMissions: active
          .where((mission) => mission.status == MissionStatus.completed)
          .length,
      totalMissions: active.length,
      weightedProgress: completedWeight / totalWeight,
    );
  }
}

class QuestFocusSelectionService {
  const QuestFocusSelectionService();

  List<QuestraTask> select({
    required Iterable<QuestraTask> tasks,
    required Iterable<Mission> missions,
    int limit = 3,
    DateTime? now,
  }) {
    if (limit <= 0) return const [];
    final today = _dateOnly(now ?? DateTime.now());
    final missionOrder = {
      for (final mission in missions) mission.id: mission.orderIndex,
    };
    final completedIds = tasks
        .where((task) => task.status == TaskStatus.completed)
        .map((task) => task.id)
        .toSet();
    final candidates = tasks.where((task) {
      if (!task.isOpen || task.status == TaskStatus.deferred) return false;
      return task.dependencyIds.every(completedIds.contains);
    }).toList();
    candidates.sort((a, b) {
      final status = _statusScore(a.status).compareTo(_statusScore(b.status));
      if (status != 0) return status;
      final scheduled = _dateScore(a, today).compareTo(_dateScore(b, today));
      if (scheduled != 0) return scheduled;
      final mission = (missionOrder[a.missionId] ?? 1 << 20).compareTo(
        missionOrder[b.missionId] ?? 1 << 20,
      );
      if (mission != 0) return mission;
      return a.orderIndex.compareTo(b.orderIndex);
    });
    return candidates.take(limit.clamp(1, 3)).toList(growable: false);
  }

  int _statusScore(TaskStatus status) => switch (status) {
        TaskStatus.inProgress => 0,
        TaskStatus.ready => 1,
        TaskStatus.pending => 2,
        _ => 3,
      };

  int _dateScore(QuestraTask task, DateTime today) {
    final date = task.scheduledDate ?? task.dueDate;
    if (date == null) return 2;
    final value = _dateOnly(date);
    if (value.isBefore(today)) return 0;
    if (value.isAtSameMomentAs(today)) return 1;
    return 3;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
