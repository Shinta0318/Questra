import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import 'quest_controller.dart';

class QuestRouteScreen extends ConsumerWidget {
  const QuestRouteScreen({required this.questId, super.key});
  final String questId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref
        .watch(questControllerProvider)
        .where((q) => q.id == questId)
        .firstOrNull;
    final missions =
        ref
            .watch(missionControllerProvider)
            .where(
              (m) =>
                  m.questId == questId &&
                  m.routeState != MissionRouteState.removed,
            )
            .toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return Scaffold(
      appBar: AppBar(title: const Text('Quest Route')),
      body: QuestraResponsiveListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            quest?.title ?? 'Quest',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text('達成までの道筋。Taskの本文はここへ複製しません。'),
          const SizedBox(height: 18),
          for (var i = 0; i < missions.length; i++)
            QuestraCard(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(missions[i].title),
                subtitle: Text(
                  '${missions[i].required ? '必須' : '任意'}${missions[i].dependencyIds.isEmpty ? '' : ' / 前提 ${missions[i].dependencyIds.length}件'}',
                ),
                trailing: Icon(
                  missions[i].status == MissionStatus.completed
                      ? Icons.verified
                      : Icons.chevron_right,
                ),
                onTap: () => context.push(
                  AppRoutes.missionDetail(questId, missions[i].id),
                ),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: const Text('Arcと航路を見直す'),
          ),
        ],
      ),
    );
  }
}
