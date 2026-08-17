import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/performance/grouped_collection_index.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_presence.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/layout/questra_journey_scaffold.dart';
import '../../widgets/persistence_sync_banner.dart';
import '../../widgets/questra_card.dart';
import '../arc/arc_expression_engine.dart';
import '../arc/arc_guidance_providers.dart';
import '../auth/auth_controller.dart';
import '../quest/quest_controller.dart';
import '../signal/mission_signal_model.dart';
import '../signal/signal_providers.dart';
import '../task/task_controller.dart';
import '../task/task_model.dart';
import 'mission_controller.dart';
import 'mission_model.dart';
import 'widgets/mission_card.dart';
import 'widgets/mission_card_presentation.dart';

class MissionScreen extends ConsumerWidget {
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(missionControllerProvider);
    final tasks = ref.watch(taskControllerProvider);
    final quests = ref.watch(questControllerProvider);
    final profile = ref.watch(authControllerProvider).profile;
    final syncState = ref.watch(missionSyncControllerProvider);
    final signals = ref
        .watch(missionSignalServiceProvider)
        .generate(quests: quests, missions: missions, now: DateTime.now());
    final expressionEngine = ref.watch(arcExpressionEngineProvider);
    final arcExpression = expressionEngine.resolveJourney(
      quests: const [],
      missions: missions,
      trails: const [],
    );
    final completedMissionIds = missions
        .where((mission) => mission.status == MissionStatus.completed)
        .map((mission) => mission.id)
        .toSet();
    final tasksByMission = GroupedCollectionIndex<String, QuestraTask>.build(
      tasks,
      keyOf: (task) => task.missionId,
    );
    final missionTitles = {
      for (final mission in missions) mission.id: mission.title,
    };

    return QuestraJourneyScaffold(
      title: 'Mission',
      actions: [
        IconButton(
          tooltip: 'Task一覧',
          onPressed: () => context.push(AppRoutes.task),
          icon: const Icon(Icons.checklist_outlined),
        ),
      ],
      child: QuestraResponsiveListView(
        onRefresh: profile == null
            ? null
            : () async {
                final questIds = quests
                    .map((quest) => quest.id)
                    .toList(growable: false);
                await ref
                    .read(missionControllerProvider.notifier)
                    .loadForQuests(questIds);
                await ref
                    .read(taskControllerProvider.notifier)
                    .loadForQuestIds(questIds);
              },
        padding: const EdgeInsets.all(20),
        children: [
          PersistenceSyncBanner(
            state: syncState,
            onDismiss: () =>
                ref.read(missionSyncControllerProvider.notifier).clear(),
          ),
          if (syncState.isActive) const SizedBox(height: 12),
          ArcPresence(
            surface: ArcPresenceSurface.mission,
            emotion: arcExpression.emotion,
            message: 'MissionはQuestへ近づいたと分かる中間成果。Taskで少しずつ形にしよう。',
          ),
          const SizedBox(height: 16),
          if (signals.isNotEmpty) ...[
            _MissionSignalPanel(signals: signals.take(3).toList()),
            const SizedBox(height: 16),
          ],
          if (missions.isEmpty)
            ArcEmptyState(
              title: 'まだMissionがありません',
              emotion: expressionEngine
                  .resolve(
                    const ArcExpressionContext(
                      moment: ArcExpressionMoment.empty,
                    ),
                  )
                  .emotion,
              message: 'Quest詳細でArcと航路を描くと、ここに中間成果が並びます。',
              actionLabel: 'Questを見る',
              icon: Icons.travel_explore_outlined,
              onAction: () => context.go(AppRoutes.quest),
            )
          else
            for (final mission in missions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MissionCard(
                  mission: mission,
                  tasks: tasksByMission.valuesFor(mission.id),
                  completedMissionIds: completedMissionIds,
                  parentMissionTitle: mission.parentMissionId == null
                      ? null
                      : missionTitles[mission.parentMissionId],
                  menuActions: const [
                    MissionCardMenuAction.consultArc,
                    MissionCardMenuAction.viewSupport,
                    MissionCardMenuAction.reviewTasks,
                  ],
                  onPrimaryPressed: (presentation) =>
                      _openPrimary(context, mission, presentation),
                  onMenuSelected: (action) {
                    final detail = AppRoutes.missionDetail(
                      mission.questId,
                      mission.id,
                    );
                    switch (action) {
                      case MissionCardMenuAction.consultArc:
                        context.push(
                          AppRoutes.arcForMission(
                            questId: mission.questId,
                            missionId: mission.id,
                            prompt: '「${mission.title}」を進める次の一歩を相談したい。',
                            returnTo: detail,
                          ),
                        );
                        return;
                      case MissionCardMenuAction.viewSupport:
                        context.push(
                          AppRoutes.missionSupport(mission.questId, mission.id),
                        );
                        return;
                      default:
                        context.push(detail);
                        return;
                    }
                  },
                ),
              ),
        ],
      ),
    );
  }

  void _openPrimary(
    BuildContext context,
    Mission mission,
    MissionCardPresentation presentation,
  ) {
    final task = presentation.nextTask;
    if (task != null &&
        (presentation.primaryAction == MissionCardPrimaryAction.startNextTask ||
            presentation.primaryAction ==
                MissionCardPrimaryAction.resumeTask)) {
      context.push(AppRoutes.taskDetail(mission.questId, mission.id, task.id));
      return;
    }
    context.push(AppRoutes.missionDetail(mission.questId, mission.id));
  }
}

class _MissionSignalPanel extends StatelessWidget {
  const _MissionSignalPanel({required this.signals});

  final List<MissionSignal> signals;

  @override
  Widget build(BuildContext context) => QuestraCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Signal', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Arcが今のMission状況から、次の一歩を照らします。'),
        const SizedBox(height: 12),
        for (final signal in signals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MissionSignalTile(signal: signal),
          ),
      ],
    ),
  );
}

class _MissionSignalTile extends StatelessWidget {
  const _MissionSignalTile({required this.signal});

  final MissionSignal signal;

  @override
  Widget build(BuildContext context) {
    final color = switch (signal.severity) {
      MissionSignalSeverity.urgent => Theme.of(context).colorScheme.tertiary,
      MissionSignalSeverity.focus => Theme.of(context).colorScheme.primary,
      MissionSignalSeverity.calm => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_none_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(signal.message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
