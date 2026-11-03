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

class QuestFocusSelection {
  const QuestFocusSelection({required this.tasks});

  final List<QuestraTask> tasks;

  QuestraTask? get primaryTask => tasks.firstOrNull;
  List<QuestraTask> get secondaryTasks =>
      tasks.skip(1).take(2).toList(growable: false);
  bool get isEmpty => tasks.isEmpty;

  String parentLabelFor(QuestraTask task) {
    final quest = task.questTitle.isEmpty ? 'Quest' : task.questTitle;
    final mission = task.missionTitle.isEmpty ? 'Mission' : task.missionTitle;
    return '$quest  /  $mission';
  }

  String trailPromptFor(QuestraTask task) =>
      '${task.title}を完了しました。この一歩をTrailに残せます。';

  String horizonPromptFor(QuestraTask task) =>
      '${parentLabelFor(task)}から、次の一歩へ進めます。';
}

class QuestFocusSelectionService {
  const QuestFocusSelectionService();

  QuestFocusSelection selectTodayFocus({
    required Iterable<QuestraTask> tasks,
    required Iterable<Mission> missions,
    Set<String>? eligibleQuestIds,
    DateTime? now,
  }) => QuestFocusSelection(
    tasks: select(
      tasks: tasks,
      missions: missions,
      eligibleQuestIds: eligibleQuestIds,
      now: now,
    ),
  );

  List<QuestraTask> select({
    required Iterable<QuestraTask> tasks,
    required Iterable<Mission> missions,
    Set<String>? eligibleQuestIds,
    int limit = 3,
    DateTime? now,
  }) {
    if (limit <= 0) return const [];
    final today = _dateOnly(now ?? DateTime.now());
    final missionOrder = {
      for (final mission in missions) mission.id: mission.orderIndex,
    };
    final missionById = {for (final mission in missions) mission.id: mission};
    final completedByMission = <String, Set<String>>{};
    for (final task in tasks) {
      if (task.status == TaskStatus.completed) {
        completedByMission.putIfAbsent(task.missionId, () => {}).add(task.id);
      }
    }
    final candidates = tasks.where((task) {
      if (eligibleQuestIds != null &&
          !eligibleQuestIds.contains(task.questId)) {
        return false;
      }
      if (!task.isOpen ||
          task.status == TaskStatus.deferred ||
          task.status == TaskStatus.blocked) {
        return false;
      }
      final mission = missionById[task.missionId];
      if (mission != null &&
          (mission.questId != task.questId ||
              mission.status != MissionStatus.todo ||
              mission.routeState != MissionRouteState.active)) {
        return false;
      }
      final completedIds =
          completedByMission[task.missionId] ?? const <String>{};
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
