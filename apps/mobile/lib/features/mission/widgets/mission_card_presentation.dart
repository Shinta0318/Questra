import '../../task/task_model.dart';
import '../mission_model.dart';

enum MissionCardPrimaryAction {
  viewTasks,
  startNextTask,
  resumeTask,
  viewCompleted,
  viewDependencies,
}

class MissionCardPresentation {
  const MissionCardPresentation({
    required this.completedTasks,
    required this.totalTasks,
    required this.progress,
    required this.primaryAction,
    required this.primaryLabel,
    required this.statusLabel,
    required this.nextTask,
  });

  final int completedTasks;
  final int totalTasks;
  final double progress;
  final MissionCardPrimaryAction primaryAction;
  final String primaryLabel;
  final String statusLabel;
  final QuestraTask? nextTask;

  factory MissionCardPresentation.resolve({
    required Mission mission,
    required Iterable<QuestraTask> tasks,
    required Set<String> completedMissionIds,
  }) {
    final ordered = tasks.toList(growable: false)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final required = ordered.where((task) => task.required).toList();
    final completed = required
        .where((task) => task.status == TaskStatus.completed)
        .length;
    final dependencyBlocked = mission.dependencyIds.any(
      (id) => !completedMissionIds.contains(id),
    );
    final open = ordered.where((task) => task.isOpen).toList();
    final active = open
        .where((task) => task.status == TaskStatus.inProgress)
        .firstOrNull;
    final ready = open
        .where((task) => task.status == TaskStatus.ready)
        .firstOrNull;
    final next = active ?? ready ?? open.firstOrNull;
    final allDone =
        mission.status == MissionStatus.completed ||
        (required.isNotEmpty && completed == required.length);
    final blocked =
        !allDone &&
        (dependencyBlocked ||
            (open.isNotEmpty &&
                open.every((task) => task.status == TaskStatus.blocked)));

    final action = allDone
        ? MissionCardPrimaryAction.viewCompleted
        : blocked
        ? MissionCardPrimaryAction.viewDependencies
        : active != null
        ? MissionCardPrimaryAction.resumeTask
        : ready != null
        ? MissionCardPrimaryAction.startNextTask
        : MissionCardPrimaryAction.viewTasks;
    final fallbackProgress = mission.progressPercent.clamp(0, 100) / 100;

    return MissionCardPresentation(
      completedTasks: completed,
      totalTasks: required.length,
      progress: required.isEmpty
          ? fallbackProgress
          : completed / required.length,
      primaryAction: action,
      primaryLabel: switch (action) {
        MissionCardPrimaryAction.viewTasks => 'Taskを見る',
        MissionCardPrimaryAction.startNextTask => '次のTaskを始める',
        MissionCardPrimaryAction.resumeTask => '続きから',
        MissionCardPrimaryAction.viewCompleted => '完了内容を見る',
        MissionCardPrimaryAction.viewDependencies => '前提を確認',
      },
      statusLabel: switch (action) {
        MissionCardPrimaryAction.viewCompleted => '完了',
        MissionCardPrimaryAction.viewDependencies => '前提待ち',
        MissionCardPrimaryAction.resumeTask => '進行中',
        MissionCardPrimaryAction.startNextTask => '開始できます',
        MissionCardPrimaryAction.viewTasks => '準備中',
      },
      nextTask: next,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
