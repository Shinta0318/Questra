import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../task/task_controller.dart';
import '../task/task_model.dart';
import 'mission_controller.dart';

class MissionDetailScreen extends ConsumerWidget {
  const MissionDetailScreen({required this.missionId, super.key});
  final String missionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mission = ref
        .watch(missionControllerProvider)
        .where((item) => item.id == missionId)
        .firstOrNull;
    final tasks =
        ref
            .watch(taskControllerProvider)
            .where((task) => task.missionId == missionId)
            .toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (mission == null) {
      return const Scaffold(body: Center(child: Text('Missionが見つかりません。')));
    }
    final requiredTasks = tasks.where((task) => task.required).toList();
    final completedTasks = requiredTasks
        .where((task) => task.status == TaskStatus.completed)
        .length;
    final progress = requiredTasks.isEmpty
        ? mission.progressPercent / 100
        : completedTasks / requiredTasks.length;
    final canConfirm =
        requiredTasks.isNotEmpty &&
        requiredTasks.every((task) => task.status == TaskStatus.completed);
    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: QuestraResponsiveListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'QUEST  ${mission.questTitle}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          const Text('MISSION', style: TextStyle(fontWeight: FontWeight.w900)),
          Text(mission.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            mission.objective.isNotEmpty
                ? mission.objective
                : mission.description,
          ),
          const SizedBox(height: 16),
          QuestraCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'このMissionで達成すること',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  mission.objective.isNotEmpty
                      ? mission.objective
                      : mission.description,
                ),
                const SizedBox(height: 12),
                Text(
                  'Mission完了条件\n${mission.successCondition.isNotEmpty ? mission.successCondition : mission.doneCondition}',
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 6),
                Text(
                  requiredTasks.isEmpty
                      ? 'Task未作成・Mission進捗 ${mission.progressPercent}%'
                      : '必須Task $completedTasks / ${requiredTasks.length} 完了',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'このMissionを進めるTask',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            const Text('このMissionのTaskはまだ生成されていません。')
          else
            for (final task in tasks) _TaskTile(task: task),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canConfirm
                ? () => ref
                      .read(missionControllerProvider.notifier)
                      .confirmMissionSuccess(mission.id)
                : null,
            icon: const Icon(Icons.verified_outlined),
            label: const Text('中間成果を確認してMission達成'),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});
  final QuestraTask task;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(
          AppRoutes.taskDetail(task.questId, task.missionId, task.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                task.status == TaskStatus.completed
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TASK  ${task.status.label}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      task.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (task.doneCondition.isNotEmpty)
                      Text(
                        task.doneCondition,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    ),
  );
}
