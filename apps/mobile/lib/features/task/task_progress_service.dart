import 'task_model.dart';

class TaskProgressSnapshot {
  const TaskProgressSnapshot({
    required this.completed,
    required this.total,
    required this.hasTasks,
  });

  final int completed;
  final int total;
  final bool hasTasks;

  int get percent => total == 0
      ? hasTasks
            ? 100
            : 0
      : ((completed / total) * 100).round();
  bool get allRequiredCompleted => hasTasks && completed == total;
  bool get hasOptionalTasksOnly => hasTasks && total == 0;
}

class TaskProgressService {
  const TaskProgressService();

  TaskProgressSnapshot forMission(Iterable<QuestraTask> tasks) {
    final required = tasks
        .where((task) => task.required)
        .toList(growable: false);
    return TaskProgressSnapshot(
      completed: required
          .where((task) => task.status == TaskStatus.completed)
          .length,
      total: required.length,
      hasTasks: tasks.isNotEmpty,
    );
  }

  QuestraTask? recommendToday(
    Iterable<QuestraTask> tasks, {
    int? availableMinutes,
  }) {
    final completed = tasks
        .where((task) => task.status == TaskStatus.completed)
        .map((task) => task.id)
        .toSet();
    final candidates =
        tasks
            .where(
              (task) =>
                  task.isOpen &&
                  task.status != TaskStatus.blocked &&
                  task.dependencyIds.every(completed.contains) &&
                  (availableMinutes == null ||
                      task.estimatedEffortMinutes == null ||
                      task.estimatedEffortMinutes! <= availableMinutes),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final scheduled = _dateRank(
              a.scheduledDate,
            ).compareTo(_dateRank(b.scheduledDate));
            return scheduled != 0
                ? scheduled
                : a.orderIndex.compareTo(b.orderIndex);
          });
    return candidates.isEmpty ? null : candidates.first;
  }

  int _dateRank(DateTime? date) => date?.millisecondsSinceEpoch ?? 1 << 62;
}
