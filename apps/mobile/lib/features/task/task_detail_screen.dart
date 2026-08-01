import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import 'task_controller.dart';
import 'task_model.dart';

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
      return const Scaffold(body: Center(child: Text('Taskが見つかりません。')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Taskの詳細')),
      body: QuestraResponsiveListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('${task.questTitle} / ${task.missionTitle}'),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: task.status == TaskStatus.completed
                ? null
                : () => ref
                      .read(taskControllerProvider.notifier)
                      .complete(task.id),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              task.status == TaskStatus.completed ? '完了済み' : 'Taskを完了',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: task.status == TaskStatus.pending
                    ? () => ref
                          .read(taskControllerProvider.notifier)
                          .start(task.id)
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('開始'),
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
}

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
