import '../../task/task_model.dart';
import '../../task/task_availability_service.dart';
import '../../task/task_progress_service.dart';
import '../mission_model.dart';

enum MissionCardPrimaryAction {
  viewTasks,
  startNextTask,
  resumeTask,
  reviewOutcome,
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
    final snapshot = const TaskProgressService().forMission(ordered);
    final dependencyBlocked = mission.dependencyIds.any(
      (id) => !completedMissionIds.contains(id),
    );
    final open = ordered.where((task) => task.isOpen).toList();
    const availabilityService = TaskAvailabilityService();
    final available = open
        .where(
          (task) =>
              availabilityService.evaluate(task, ordered).canStart ||
              availabilityService.evaluate(task, ordered).canComplete,
        )
        .toList(growable: false);
    final active = open
        .where(
          (task) =>
              task.status == TaskStatus.inProgress &&
              availabilityService.evaluate(task, ordered).canComplete,
        )
        .firstOrNull;
    final ready = available
        .where(
          (task) =>
              task.status == TaskStatus.ready ||
              task.status == TaskStatus.pending,
        )
        .firstOrNull;
    final next = active ?? ready ?? available.firstOrNull;
    final missionConfirmed =
        mission.status == MissionStatus.completed &&
        mission.successConfirmedAt != null;
    final awaitingOutcome = !missionConfirmed && snapshot.allRequiredCompleted;
    final blocked =
        !missionConfirmed &&
        !awaitingOutcome &&
        (dependencyBlocked || (open.isNotEmpty && available.isEmpty));

    final action = missionConfirmed
        ? MissionCardPrimaryAction.viewCompleted
        : awaitingOutcome
        ? MissionCardPrimaryAction.reviewOutcome
        : blocked
        ? MissionCardPrimaryAction.viewDependencies
        : active != null
        ? MissionCardPrimaryAction.resumeTask
        : ready != null
        ? MissionCardPrimaryAction.startNextTask
        : MissionCardPrimaryAction.viewTasks;
    return MissionCardPresentation(
      completedTasks: snapshot.completed,
      totalTasks: snapshot.total,
      progress: snapshot.percent / 100,
      primaryAction: action,
      primaryLabel: switch (action) {
        MissionCardPrimaryAction.viewTasks => 'Taskを見る',
        MissionCardPrimaryAction.startNextTask => '次のTaskを始める',
        MissionCardPrimaryAction.resumeTask => '続きから',
        MissionCardPrimaryAction.reviewOutcome => '成果を確認',
        MissionCardPrimaryAction.viewCompleted => '完了内容を見る',
        MissionCardPrimaryAction.viewDependencies => '前提を確認',
      },
      statusLabel: switch (action) {
        MissionCardPrimaryAction.viewCompleted => '完了',
        MissionCardPrimaryAction.viewDependencies => '前提待ち',
        MissionCardPrimaryAction.resumeTask => '進行中',
        MissionCardPrimaryAction.reviewOutcome => '成果確認待ち',
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
