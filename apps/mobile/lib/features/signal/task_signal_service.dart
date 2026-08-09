import '../../core/performance/grouped_collection_index.dart';
import '../auth/auth_state.dart';
import '../task/task_availability_service.dart';
import '../task/task_model.dart';
import 'task_signal_model.dart';

class TaskSignalService {
  const TaskSignalService();

  List<TaskSignal> generate({
    required List<QuestraTask> tasks,
    required DateTime now,
    SignalFrequency frequency = SignalFrequency.balanced,
  }) {
    final signals = <TaskSignal>[];
    final tasksByMission = GroupedCollectionIndex<String, QuestraTask>.build(
      tasks,
      keyOf: (task) => task.missionId,
    );
    final completedByMission = <String, Set<String>>{
      for (final missionId in tasks.map((task) => task.missionId).toSet())
        missionId: tasksByMission
            .valuesFor(missionId)
            .where((task) => task.status == TaskStatus.completed)
            .map((task) => task.id)
            .toSet(),
    };
    final availabilityByTaskId = <String, TaskAvailability>{};
    for (final task in tasks) {
      final availability = const TaskAvailabilityService().evaluate(
        task,
        tasksByMission.valuesFor(task.missionId),
        completedTaskIds: completedByMission[task.missionId],
      );
      availabilityByTaskId[task.id] = availability;
      if (!availability.canStart && !availability.canComplete) continue;

      final dueDate = task.dueDate;
      if (dueDate != null) {
        final daysUntil = _dateOnly(dueDate).difference(_dateOnly(now)).inDays;
        if (daysUntil < 0) {
          signals.add(
            _signal(
              task,
              type: TaskSignalType.overdue,
              severity: TaskSignalSeverity.urgent,
              title: '期限を過ぎたTaskがあります',
              message: '「${task.title}」を責めずに見直そう。難しければArcと小さく分けられます。',
            ),
          );
          continue;
        }
        if (daysUntil == 0) {
          signals.add(
            _signal(
              task,
              type: TaskSignalType.dueToday,
              severity: TaskSignalSeverity.focus,
              title: '今日が期限のTask',
              message: '「${task.title}」が今日の航路にあります。無理のない時間から始めよう。',
            ),
          );
          continue;
        }
        if (daysUntil <= 3) {
          signals.add(
            _signal(
              task,
              type: TaskSignalType.dueSoon,
              severity: TaskSignalSeverity.focus,
              title: 'もうすぐ期限のTask',
              message: '「${task.title}」まであと$daysUntil日。今できる一歩だけ確認しよう。',
            ),
          );
          continue;
        }
      }

      final inactiveDays = now.difference(task.updatedAt).inDays;
      if (inactiveDays >= 3) {
        signals.add(
          _signal(
            task,
            type: TaskSignalType.stalled,
            severity: TaskSignalSeverity.focus,
            title: '止まっているTaskがあります',
            message: '「${task.title}」を5分でできる形に整えると、また進みやすくなります。',
          ),
        );
      }
    }

    if (signals.isEmpty) {
      final ready = tasks
          .where((task) => availabilityByTaskId[task.id]?.canStart ?? false)
          .firstOrNull;
      if (ready != null) {
        signals.add(
          _signal(
            ready,
            type: TaskSignalType.ready,
            severity: TaskSignalSeverity.calm,
            title: '次に進めるTask',
            message: '「${ready.title}」が始められます。今日は少しだけでも十分です。',
          ),
        );
      }
    }

    signals.sort((a, b) => _rank(b.severity).compareTo(_rank(a.severity)));
    return switch (frequency) {
      SignalFrequency.quiet =>
        signals
            .where((signal) => signal.severity != TaskSignalSeverity.calm)
            .take(1)
            .toList(growable: false),
      SignalFrequency.balanced => signals.take(2).toList(growable: false),
      SignalFrequency.frequent => signals.take(3).toList(growable: false),
    };
  }

  TaskSignal _signal(
    QuestraTask task, {
    required TaskSignalType type,
    required TaskSignalSeverity severity,
    required String title,
    required String message,
  }) => TaskSignal(
    type: type,
    severity: severity,
    taskId: task.id,
    questId: task.questId,
    missionId: task.missionId,
    title: title,
    message: message,
  );

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  int _rank(TaskSignalSeverity severity) => switch (severity) {
    TaskSignalSeverity.calm => 0,
    TaskSignalSeverity.focus => 1,
    TaskSignalSeverity.urgent => 2,
  };
}
