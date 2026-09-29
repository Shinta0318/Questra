import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/feature_flags/journey_action_hierarchy_feature_flags.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../quest_journey/widgets/journey_hierarchy_breadcrumb.dart';
import 'task_availability_service.dart';
import 'task_achievement_flow.dart';
import 'task_controller.dart';
import 'task_model.dart';
import 'task_mutation_banner.dart';
import 'task_mutation_state.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({required this.taskId, super.key});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref
        .watch(taskControllerProvider)
        .where((item) => item.id == taskId)
        .firstOrNull;
    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Taskの詳細')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Taskが見つかりません。'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go(AppRoutes.quest),
                child: const Text('Questへ戻る'),
              ),
            ],
          ),
        ),
      );
    }
    final missionTasks = ref
        .watch(taskControllerProvider)
        .where((item) => item.missionId == task.missionId);
    final availability = const TaskAvailabilityService().evaluate(
      task,
      missionTasks,
    );
    final mutation = ref.watch(taskMutationControllerProvider);
    final achievementPlan = task.status == TaskStatus.completed
        ? const TaskAchievementService().build(
            completedTask: task,
            allTasks: ref.watch(taskControllerProvider),
          )
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Taskの詳細')),
      body: QuestraResponsiveListView(
        padding: const EdgeInsets.all(20),
        children: [
          TaskMutationBanner(
            state: mutation,
            onRetry: () async {
              await ref.read(taskControllerProvider.notifier).retryPending();
            },
            onDiscard: () =>
                ref.read(taskControllerProvider.notifier).discardPending(),
            onDismiss: () =>
                ref.read(taskMutationControllerProvider.notifier).clear(),
          ),
          if (mutation.isActive) const SizedBox(height: 12),
          if (const JourneyActionHierarchyFeatureFlags().enabled)
            JourneyHierarchyBreadcrumb(
              questId: task.questId,
              questTitle: task.questTitle,
              missionId: task.missionId,
              missionTitle: task.missionTitle,
              currentLevel: 'Task',
            )
          else ...[
            Text(
              'QUEST  ${task.questTitle}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'MISSION  ${task.missionTitle}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
          const SizedBox(height: 12),
          const Text('具体的な行動', style: TextStyle(fontWeight: FontWeight.w900)),
          Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(task.status.label),
          const SizedBox(height: 18),
          QuestraCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(label: '実行すること', value: task.action),
                _Field(label: '目的', value: task.purpose),
                _Field(label: '完了の目印', value: task.doneCondition),
                _Field(label: '残す成果', value: task.expectedOutput),
                if (task.estimatedEffortMinutes != null)
                  _Field(
                    label: '所要時間の目安',
                    value: '${task.estimatedEffortMinutes}分',
                  ),
                if (task.scheduledDate != null)
                  _Field(
                    label: '実行予定日',
                    value: _dateLabel(task.scheduledDate!),
                  ),
                if (task.dueDate != null)
                  _Field(label: '期限', value: _dateLabel(task.dueDate!)),
                if (task.dependencyIds.isNotEmpty)
                  _Field(
                    label: '前提Task',
                    value: '${task.dependencyIds.length}件の完了後に開始',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (availability.reason != null) ...[
            Text(
              availability.reason!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (achievementPlan != null) ...[
            TaskAchievementCard(
              plan: achievementPlan,
              onTrail: () => context.go(
                AppRoutes.trailForTask(
                  questId: task.questId,
                  questTitle: task.questTitle,
                  missionId: task.missionId,
                  missionTitle: task.missionTitle,
                  taskId: task.id,
                  taskTitle: task.title,
                ),
              ),
              onNext: () {
                if (achievementPlan.missionReadyForReview) {
                  context.push(
                    AppRoutes.missionDetail(task.questId, task.missionId),
                  );
                  return;
                }
                final next = achievementPlan.nextTask;
                if (next != null) {
                  context.push(
                    AppRoutes.taskDetail(next.questId, next.missionId, next.id),
                  );
                  return;
                }
                context.push(
                  AppRoutes.questJourneyFocus(questId: task.questId),
                );
              },
              onUndo: () =>
                  ref.read(taskControllerProvider.notifier).reopen(task.id),
            ),
            const SizedBox(height: 10),
          ] else
            FilledButton.icon(
              onPressed: availability.canComplete
                  ? () => _completeAndCelebrate(context, ref, task)
                  : availability.canStart
                  ? () =>
                        ref.read(taskControllerProvider.notifier).start(task.id)
                  : null,
              icon: Icon(
                availability.canComplete
                    ? Icons.check_circle_outline
                    : Icons.play_arrow,
              ),
              label: Text(
                availability.canComplete
                    ? 'Taskを完了'
                    : availability.canStart
                    ? 'Taskを開始'
                    : '前提Taskを確認',
              ),
            ),
          const SizedBox(height: 10),
          if (achievementPlan == null)
            OutlinedButton.icon(
              key: const ValueKey('task-create-trail'),
              onPressed: () => context.go(
                AppRoutes.trailForTask(
                  questId: task.questId,
                  questTitle: task.questTitle,
                  missionId: task.missionId,
                  missionTitle: task.missionTitle,
                  taskId: task.id,
                  taskTitle: task.title,
                ),
              ),
              icon: const Icon(Icons.route_outlined),
              label: const Text('途中のTrailを残す'),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: availability.canReopen
                    ? () => ref
                          .read(taskControllerProvider.notifier)
                          .reopen(task.id)
                    : null,
                icon: const Icon(Icons.undo),
                label: const Text('完了を取り消す'),
              ),
              OutlinedButton.icon(
                onPressed: task.status == TaskStatus.completed
                    ? null
                    : () => ref
                          .read(taskControllerProvider.notifier)
                          .reschedule(
                            task.id,
                            DateTime.now().add(const Duration(days: 1)),
                          ),
                icon: const Icon(Icons.event_repeat),
                label: const Text('明日に延期'),
              ),
              TextButton(
                onPressed: task.status == TaskStatus.completed
                    ? null
                    : () => ref
                          .read(taskControllerProvider.notifier)
                          .skip(task.id),
                child: const Text('見送る'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _completeAndCelebrate(
    BuildContext context,
    WidgetRef ref,
    QuestraTask task,
  ) async {
    final controller = ref.read(taskControllerProvider.notifier);
    final completed = await controller.complete(task.id);
    if (!context.mounted || !completed) return;
    final tasks = ref.read(taskControllerProvider);
    final savedTask = tasks.where((item) => item.id == task.id).firstOrNull;
    if (savedTask == null) return;
    await showTaskAchievementJourney(
      context: context,
      completedTask: savedTask,
      allTasks: tasks,
      onUndo: () => controller.reopen(savedTask.id),
    );
  }
}

String _dateLabel(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
