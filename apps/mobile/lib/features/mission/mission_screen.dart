import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/questra_colors.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_presence.dart';
import '../../widgets/motion/questra_motion.dart';
import '../../widgets/persistence_sync_banner.dart';
import '../../widgets/questra_card.dart';
import '../arc/arc_celebration_service.dart';
import '../arc/arc_expression_engine.dart';
import '../arc/arc_guidance_providers.dart';
import '../quest/quest_guide_model.dart';
import 'mission_controller.dart';
import 'mission_model.dart';

class MissionScreen extends ConsumerWidget {
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(missionControllerProvider);
    final syncState = ref.watch(missionSyncControllerProvider);
    final expressionEngine = ref.watch(arcExpressionEngineProvider);
    final arcExpression = expressionEngine.resolveJourney(
      quests: const [],
      missions: missions,
      trails: const [],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: SafeArea(
        child: ListView(
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
              message: '小さなMissionも、ちゃんと前進だよ。今日の星をひとつ選ぼう。',
            ),
            const SizedBox(height: 16),
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
                message: 'Quest詳細からMissionを生成すると、ここに今日の一歩が並びます。',
                actionLabel: 'Questを確認',
                icon: Icons.travel_explore_outlined,
                onAction: () => context.go(AppRoutes.quest),
              )
            else
              ...missions.map(
                (mission) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: QuestraCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mission.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(mission.description),
                        const SizedBox(height: 10),
                        Text('Quest: ${mission.questTitle}'),
                        Text('Guide: ${mission.guideType.label}'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: mission.status == MissionStatus.completed
                              ? null
                              : () => _completeMission(context, ref, mission),
                          icon: Icon(
                            mission.status == MissionStatus.completed
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            color: QuestraColors.gold,
                          ),
                          label: AnimatedSwitcher(
                            duration: QuestraMotion.fast,
                            switchInCurve: QuestraMotion.standard,
                            switchOutCurve: QuestraMotion.standard,
                            child: Text(
                              key: ValueKey(mission.status),
                              mission.status == MissionStatus.completed
                                  ? '完了済み'
                                  : 'Missionを完了',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _completeMission(BuildContext context, WidgetRef ref, Mission mission) {
  final completedMission = ref
      .read(missionControllerProvider.notifier)
      .completeMission(mission.id);
  if (completedMission == null) {
    return;
  }
  showArcCelebrationSnackBar(
    context,
    ref
        .read(arcCelebrationServiceProvider)
        .build(
          event: ArcCelebrationEvent.missionCompleted,
          subject: completedMission.title,
        ),
  );
}
