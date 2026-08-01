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
    final canConfirm =
        requiredTasks.isNotEmpty &&
        requiredTasks.every((task) => task.status == TaskStatus.completed);
    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: QuestraResponsiveListView(
        padding: const EdgeInsets.all(20),
        children: [
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
                Text('中間成果', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  mission.expectedOutcome.isNotEmpty
                      ? mission.expectedOutcome
                      : mission.expectedOutput,
                ),
                const SizedBox(height: 12),
                Text(
                  '達成条件: ${mission.successCondition.isNotEmpty ? mission.successCondition : mission.doneCondition}',
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: mission.progressPercent / 100),
                const SizedBox(height: 6),
                Text('Task進捗 ${mission.progressPercent}%'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Task', style: Theme.of(context).textTheme.titleLarge),
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
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      task.status == TaskStatus.completed
          ? Icons.check_circle
          : Icons.radio_button_unchecked,
    ),
    title: Text(task.title),
    subtitle: Text(task.doneCondition),
    trailing: const Icon(Icons.chevron_right),
    onTap: () =>
        context.go(AppRoutes.taskDetail(task.questId, task.missionId, task.id)),
  );
}
