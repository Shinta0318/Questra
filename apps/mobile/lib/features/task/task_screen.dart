import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../quest/quest_controller.dart';
import 'task_controller.dart';
import 'task_model.dart';

class TaskScreen extends ConsumerWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskControllerProvider);
    final quests = ref.watch(questControllerProvider);
    final today = ref.read(taskControllerProvider.notifier).todaysTask;
    final ordered = [
      ?today,
      ...tasks.where((task) => task.id != today?.id && task.isOpen),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Task')),
      body: SafeArea(
        child: QuestraResponsiveListView(
          padding: const EdgeInsets.all(20),
          onRefresh: () => ref
              .read(taskControllerProvider.notifier)
              .loadForQuestIds(quests.map((quest) => quest.id).toList()),
          children: [
            Text('今日の一歩', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text('TaskはMissionを進めるための、今すぐ実行できる具体的な行動です。'),
            const SizedBox(height: 18),
            if (ordered.isEmpty)
              ArcEmptyState(
                title: '実行できるTaskはまだありません',
                message: 'Questの航路からMissionを開き、最初のTaskを準備しよう。',
                actionLabel: 'Questを見る',
                icon: Icons.check_circle_outline,
                onAction: () => context.go(AppRoutes.quest),
              )
            else
              for (final task in ordered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TaskCard(
                    task: task,
                    recommended: task.id == today?.id,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, required this.recommended});
  final QuestraTask task;
  final bool recommended;

  @override
  Widget build(BuildContext context, WidgetRef ref) => QuestraCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recommended)
          const Text('Arcのおすすめ', style: TextStyle(fontWeight: FontWeight.w700)),
        Text(task.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(task.action),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () =>
              context.go(AppRoutes.missionDetail(task.questId, task.missionId)),
          icon: const Icon(Icons.account_tree_outlined),
          label: Text('${task.questTitle} / ${task.missionTitle}'),
        ),
        Row(
          children: [
            if (task.estimatedEffortMinutes != null)
              Text('目安 ${task.estimatedEffortMinutes}分'),
            const Spacer(),
            FilledButton.icon(
              onPressed: task.status == TaskStatus.completed
                  ? null
                  : () => ref
                        .read(taskControllerProvider.notifier)
                        .complete(task.id),
              icon: const Icon(Icons.check),
              label: Text(task.status == TaskStatus.completed ? '完了済み' : '完了'),
            ),
            IconButton(
              tooltip: 'Taskの詳細',
              onPressed: () => context.go(
                AppRoutes.taskDetail(task.questId, task.missionId, task.id),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    ),
  );
}
