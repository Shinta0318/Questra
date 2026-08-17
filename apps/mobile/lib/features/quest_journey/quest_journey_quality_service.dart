import '../mission/mission_model.dart';
import '../task/task_model.dart';

enum JourneyQualityIssueCode {
  duplicateTask,
  dependencyCycle,
  emptyMissionOutcome,
  missionWithoutTasks,
  missionTooGranular,
  noActionableTask,
}

class JourneyQualityIssue {
  const JourneyQualityIssue({
    required this.code,
    required this.message,
    this.missionId,
    this.taskId,
  });

  final JourneyQualityIssueCode code;
  final String message;
  final String? missionId;
  final String? taskId;
}

class QuestJourneyQualityService {
  const QuestJourneyQualityService();

  List<JourneyQualityIssue> inspect({
    required Iterable<Mission> missions,
    required Iterable<QuestraTask> tasks,
  }) {
    final missionList = missions.toList(growable: false);
    final taskList = tasks.toList(growable: false);
    final issues = <JourneyQualityIssue>[];
    final normalizedTitles = <String, String>{};

    for (final task in taskList) {
      final normalized = _normalize(task.title);
      final previous = normalizedTitles[normalized];
      if (normalized.isNotEmpty && previous != null) {
        issues.add(
          JourneyQualityIssue(
            code: JourneyQualityIssueCode.duplicateTask,
            message: '同じ意味のTaskが重複しています。',
            taskId: task.id,
            missionId: task.missionId,
          ),
        );
      } else {
        normalizedTitles[normalized] = task.id;
      }
    }

    final taskById = {for (final task in taskList) task.id: task};
    for (final task in taskList) {
      if (_hasCycle(task.id, taskById, <String>{}, <String>{})) {
        issues.add(
          JourneyQualityIssue(
            code: JourneyQualityIssueCode.dependencyCycle,
            message: 'Taskの依存関係が循環しています。',
            taskId: task.id,
            missionId: task.missionId,
          ),
        );
      }
    }

    for (final mission in missionList.where((item) => item.isOutcomeMission)) {
      final children = taskList
          .where((task) => task.missionId == mission.id)
          .toList(growable: false);
      final outcome = mission.successCondition.isNotEmpty
          ? mission.successCondition
          : mission.doneCondition;
      if (outcome.trim().isEmpty) {
        issues.add(
          JourneyQualityIssue(
            code: JourneyQualityIssueCode.emptyMissionOutcome,
            message: 'Missionに確認可能な成果条件がありません。',
            missionId: mission.id,
          ),
        );
      }
      if (children.isEmpty) {
        issues.add(
          JourneyQualityIssue(
            code: JourneyQualityIssueCode.missionWithoutTasks,
            message: 'Missionを実行するTaskがありません。',
            missionId: mission.id,
          ),
        );
      } else if (children.length == 1 &&
          (children.single.estimatedEffortMinutes ?? 0) <= 120) {
        issues.add(
          JourneyQualityIssue(
            code: JourneyQualityIssueCode.missionTooGranular,
            message: '一度の行動で終わる項目はMissionではなくTaskとして扱います。',
            missionId: mission.id,
            taskId: children.single.id,
          ),
        );
      }
    }

    final completed = taskList
        .where((task) => task.status == TaskStatus.completed)
        .map((task) => task.id)
        .toSet();
    final hasActionable = taskList.any(
      (task) =>
          task.isOpen &&
          task.status != TaskStatus.deferred &&
          task.dependencyIds.every(completed.contains),
    );
    if (taskList.isNotEmpty && !hasActionable) {
      issues.add(
        const JourneyQualityIssue(
          code: JourneyQualityIssueCode.noActionableTask,
          message: '今すぐ始められるTaskがありません。',
        ),
      );
    }
    return issues;
  }

  /// A partial replan may only repair failed, unfinished Tasks in the chosen
  /// Mission. Completed work and sibling Missions stay untouched.
  Set<String> repairableTaskIds({
    required String missionId,
    required Iterable<QuestraTask> tasks,
    required Iterable<String> failedTaskIds,
  }) {
    final failed = failedTaskIds.toSet();
    return tasks
        .where(
          (task) =>
              task.missionId == missionId &&
              task.status != TaskStatus.completed &&
              failed.contains(task.id),
        )
        .map((task) => task.id)
        .toSet();
  }

  bool _hasCycle(
    String id,
    Map<String, QuestraTask> tasks,
    Set<String> visiting,
    Set<String> visited,
  ) {
    if (visiting.contains(id)) return true;
    if (visited.contains(id)) return false;
    final task = tasks[id];
    if (task == null) return false;
    visiting.add(id);
    for (final dependencyId in task.dependencyIds) {
      if (_hasCycle(dependencyId, tasks, visiting, visited)) return true;
    }
    visiting.remove(id);
    visited.add(id);
    return false;
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s　・、。,.!?！？]'), '')
      .replaceAll(RegExp(r'(する|します|を行う)$'), '');
}
