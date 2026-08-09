import '../task/task_load_state.dart';
import '../task/task_model.dart';

enum HomeTodayTaskStatus { loading, failed, actionable, completed, empty }

class HomeTodayTaskJourney {
  const HomeTodayTaskJourney({required this.status, this.task});

  final HomeTodayTaskStatus status;
  final QuestraTask? task;
}

class HomeTodayTaskJourneyService {
  const HomeTodayTaskJourneyService();

  HomeTodayTaskJourney resolve({
    required Iterable<QuestraTask> tasks,
    required TaskLoadState loadState,
    required DateTime now,
    QuestraTask? recommendedTask,
    bool hasActiveJourney = false,
    bool isSignedIn = false,
  }) {
    if (loadState.status == TaskLoadStatus.loading ||
        (loadState.status == TaskLoadStatus.idle &&
            hasActiveJourney &&
            isSignedIn &&
            tasks.isEmpty)) {
      return const HomeTodayTaskJourney(status: HomeTodayTaskStatus.loading);
    }
    if (loadState.status == TaskLoadStatus.failed) {
      return const HomeTodayTaskJourney(status: HomeTodayTaskStatus.failed);
    }
    if (recommendedTask != null) {
      return HomeTodayTaskJourney(
        status: HomeTodayTaskStatus.actionable,
        task: recommendedTask,
      );
    }

    QuestraTask? latestCompleted;
    for (final task in tasks) {
      final completedAt = task.completedAt;
      if (task.status != TaskStatus.completed || completedAt == null) continue;
      if (!_isSameLocalDay(completedAt, now)) continue;
      if (latestCompleted == null ||
          completedAt.isAfter(latestCompleted.completedAt!)) {
        latestCompleted = task;
      }
    }
    if (latestCompleted != null) {
      return HomeTodayTaskJourney(
        status: HomeTodayTaskStatus.completed,
        task: latestCompleted,
      );
    }
    return const HomeTodayTaskJourney(status: HomeTodayTaskStatus.empty);
  }

  bool _isSameLocalDay(DateTime left, DateTime right) {
    final localLeft = left.toLocal();
    final localRight = right.toLocal();
    return localLeft.year == localRight.year &&
        localLeft.month == localRight.month &&
        localLeft.day == localRight.day;
  }
}
