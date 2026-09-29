import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/forms/questra_modal_sheet.dart';
import '../../widgets/questra_card.dart';
import '../arc/arc_celebration_service.dart';
import 'task_availability_service.dart';
import 'task_model.dart';

enum TaskAchievementAction { trail, nextTask, missionReview, undo }

class TaskAchievementPlan {
  const TaskAchievementPlan({
    required this.completedTask,
    required this.missionReadyForReview,
    required this.message,
    this.nextTask,
  });

  final QuestraTask completedTask;
  final QuestraTask? nextTask;
  final bool missionReadyForReview;
  final String message;

  String get nextActionLabel {
    if (missionReadyForReview) return 'Missionの成果を確認';
    if (nextTask != null) return '次のTaskを見る';
    return 'Questの航路を見る';
  }
}

class TaskAchievementService {
  const TaskAchievementService();

  TaskAchievementPlan build({
    required QuestraTask completedTask,
    required Iterable<QuestraTask> allTasks,
  }) {
    final questTasks = allTasks
        .where((task) => task.questId == completedTask.questId)
        .toList(growable: false);
    final missionTasks = questTasks
        .where((task) => task.missionId == completedTask.missionId)
        .toList(growable: false);
    final requiredMissionTasks = missionTasks.where((task) => task.required);
    final missionReady =
        requiredMissionTasks.isNotEmpty &&
        requiredMissionTasks.every(
          (task) => task.status == TaskStatus.completed,
        );
    final candidates =
        questTasks
            .where((task) => task.id != completedTask.id && task.isOpen)
            .toList()
          ..sort((a, b) {
            final aSameMission = a.missionId == completedTask.missionId;
            final bSameMission = b.missionId == completedTask.missionId;
            if (aSameMission != bSameMission) return aSameMission ? -1 : 1;
            return a.orderIndex.compareTo(b.orderIndex);
          });
    final nextTask = candidates.where((task) {
      final siblings = questTasks.where(
        (item) => item.missionId == task.missionId,
      );
      final availability = const TaskAvailabilityService().evaluate(
        task,
        siblings,
      );
      return availability.canStart || availability.canComplete;
    }).firstOrNull;
    final message = missionReady
        ? '必須Taskがそろいました。Trailを残したら、Missionの成果も確認できます。'
        : nextTask != null
        ? '次は「${nextTask.title}」へ進めます。今の気づきはTrailに残しておこう。'
        : 'ここまでの経験をTrailに残してから、Questの航路を見直そう。';

    return TaskAchievementPlan(
      completedTask: completedTask,
      nextTask: nextTask,
      missionReadyForReview: missionReady,
      message: message,
    );
  }
}

class TaskAchievementCard extends StatelessWidget {
  const TaskAchievementCard({
    required this.plan,
    required this.onTrail,
    required this.onNext,
    this.onUndo,
    super.key,
  });

  final TaskAchievementPlan plan;
  final VoidCallback onTrail;
  final VoidCallback onNext;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final moment = const ArcCelebrationService().build(
      event: ArcCelebrationEvent.taskCompleted,
      subject: plan.completedTask.title,
    );
    return Semantics(
      container: true,
      label: '${moment.title}。${plan.message}',
      child: QuestraCard(
        key: const ValueKey('task-achievement-card'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArcWidget(
                  emotion: moment.emotion,
                  size: 72,
                  showSpeechBubble: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moment.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(moment.message),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(plan.message),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('task-achievement-trail'),
              onPressed: onTrail,
              icon: const Icon(Icons.route_outlined),
              label: const Text('Trailに残す'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('task-achievement-next'),
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(plan.nextActionLabel),
            ),
            if (onUndo != null)
              TextButton(
                key: const ValueKey('task-achievement-undo'),
                onPressed: onUndo,
                child: const Text('完了を取り消す'),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showTaskAchievementJourney({
  required BuildContext context,
  required QuestraTask completedTask,
  required Iterable<QuestraTask> allTasks,
  required Future<bool> Function() onUndo,
}) async {
  final plan = const TaskAchievementService().build(
    completedTask: completedTask,
    allTasks: allTasks,
  );
  final action = await showQuestraModalSheet<TaskAchievementAction>(
    context: context,
    builder: (sheetContext) => QuestraModalSheet(
      title: '一歩進みました',
      dark: true,
      hasUnsavedChanges: () => false,
      child: TaskAchievementCard(
        plan: plan,
        onTrail: () =>
            QuestraModalSheet.finish(sheetContext, TaskAchievementAction.trail),
        onNext: () => QuestraModalSheet.finish(
          sheetContext,
          plan.missionReadyForReview
              ? TaskAchievementAction.missionReview
              : TaskAchievementAction.nextTask,
        ),
        onUndo: () =>
            QuestraModalSheet.finish(sheetContext, TaskAchievementAction.undo),
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case TaskAchievementAction.trail:
      context.push(
        AppRoutes.trailForTask(
          questId: completedTask.questId,
          questTitle: completedTask.questTitle,
          missionId: completedTask.missionId,
          missionTitle: completedTask.missionTitle,
          taskId: completedTask.id,
          taskTitle: completedTask.title,
        ),
      );
      return;
    case TaskAchievementAction.missionReview:
      context.push(
        AppRoutes.missionDetail(completedTask.questId, completedTask.missionId),
      );
      return;
    case TaskAchievementAction.nextTask:
      final next = plan.nextTask;
      if (next != null) {
        context.push(
          AppRoutes.taskDetail(next.questId, next.missionId, next.id),
        );
      } else {
        context.push(
          AppRoutes.questJourneyFocus(questId: completedTask.questId),
        );
      }
      return;
    case TaskAchievementAction.undo:
      await onUndo();
      return;
  }
}
