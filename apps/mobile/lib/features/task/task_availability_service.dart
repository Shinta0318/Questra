import 'task_model.dart';

class TaskAvailability {
  const TaskAvailability({
    required this.canStart,
    required this.canComplete,
    required this.canReopen,
    required this.blockingDependencyIds,
    this.reason,
  });

  final bool canStart;
  final bool canComplete;
  final bool canReopen;
  final List<String> blockingDependencyIds;
  final String? reason;

  bool get isDependencyBlocked => blockingDependencyIds.isNotEmpty;
}

class TaskAvailabilityService {
  const TaskAvailabilityService();

  TaskAvailability evaluate(
    QuestraTask task,
    Iterable<QuestraTask> missionTasks, {
    Set<String>? completedTaskIds,
  }) {
    if (task.status == TaskStatus.completed) {
      return TaskAvailability(
        canStart: false,
        canComplete: false,
        canReopen: true,
        blockingDependencyIds: [],
      );
    }
    if (task.status == TaskStatus.skipped ||
        task.status == TaskStatus.deferred ||
        task.status == TaskStatus.cancelled) {
      return TaskAvailability(
        canStart: false,
        canComplete: false,
        canReopen: false,
        blockingDependencyIds: [],
        reason: task.status == TaskStatus.deferred
            ? 'このTaskは「あとで」に移動されています。'
            : 'このTaskは現在の航路では実行しません。',
      );
    }
    if (task.status == TaskStatus.blocked) {
      return const TaskAvailability(
        canStart: false,
        canComplete: false,
        canReopen: false,
        blockingDependencyIds: [],
        reason: 'このTaskは保留中です。',
      );
    }

    final completedIds = completedTaskIds ??
        missionTasks
            .where((item) => item.status == TaskStatus.completed)
            .map((item) => item.id)
            .toSet();
    final unresolved = task.dependencyIds
        .where((id) => !completedIds.contains(id))
        .toList(growable: false);
    if (unresolved.isNotEmpty) {
      return TaskAvailability(
        canStart: false,
        canComplete: false,
        canReopen: false,
        blockingDependencyIds: unresolved,
        reason: '前提Taskを${unresolved.length}件完了すると開始できます。',
      );
    }

    return TaskAvailability(
      canStart:
          task.status == TaskStatus.pending || task.status == TaskStatus.ready,
      canComplete: task.status == TaskStatus.inProgress,
      canReopen: false,
      blockingDependencyIds: const [],
    );
  }
}
