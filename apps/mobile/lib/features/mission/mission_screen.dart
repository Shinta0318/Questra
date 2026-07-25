import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/experience/experience_settings_controller.dart';
import '../../core/experience/haptic_feedback_service.dart';
import '../../core/experience/sound_effect_service.dart';
import '../../core/theme/questra_colors.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_presence.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/menu/questra_action_menu.dart';
import '../../widgets/motion/questra_motion.dart';
import '../../widgets/persistence_sync_banner.dart';
import '../../widgets/questra_card.dart';
import '../arc/arc_celebration_service.dart';
import '../arc/arc_expression_engine.dart';
import '../arc/arc_guidance_providers.dart';
import '../arc/arc_motion_controller.dart';
import '../auth/auth_controller.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_guide_model.dart';
import '../signal/mission_signal_model.dart';
import '../signal/signal_providers.dart';
import 'mission_controller.dart';
import 'mission_model.dart';

class MissionScreen extends ConsumerWidget {
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(missionControllerProvider);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: SafeArea(
        child: QuestraResponsiveListView(
          onRefresh: profile == null
              ? null
              : () =>
                  ref.read(missionControllerProvider.notifier).loadForQuests(
                        quests.map((quest) => quest.id).toList(growable: false),
                      ),
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
                message: 'Quest詳細からMissionを生成すると、ここに今日の一歩が並びます。',
                actionLabel: 'Questを確認',
                icon: Icons.travel_explore_outlined,
                onAction: () => context.go(AppRoutes.quest),
              )
            else
              ...missions.map(
                (mission) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InteractiveMissionCard(mission: mission),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InteractiveMissionCard extends ConsumerWidget {
  const _InteractiveMissionCard({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(experienceSettingsControllerProvider);
    final canComplete = mission.status != MissionStatus.completed;
    final card = QuestraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mission.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(mission.description),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () =>
                context.go('${AppRoutes.quest}/${mission.questId}'),
            icon: const Icon(Icons.route_outlined, size: 18),
            label: Text('Quest「${mission.questTitle}」のMission'),
          ),
          Text('進め方: ${mission.guideType.label}'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: mission.progressPercent / 100,
                    minHeight: 8,
                    backgroundColor: QuestraColors.cloud,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      QuestraColors.gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${mission.progressPercent}%',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              PopupMenuButton<int>(
                tooltip: '進捗を更新',
                icon: const Icon(Icons.tune_outlined),
                onSelected: (value) => ref
                    .read(missionControllerProvider.notifier)
                    .updateProgress(mission.id, value),
                itemBuilder: (context) => [
                  for (final value in const [0, 25, 50, 75, 100])
                    PopupMenuItem(value: value, child: Text('$value%')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          QuestraActionButton(
            onPressed: canComplete
                ? () => _completeMission(
                      context,
                      ref,
                      mission,
                      source: _MissionCompletionSource.button,
                    )
                : null,
            icon: Icon(
              canComplete ? Icons.check_circle_outline : Icons.check_circle,
              color: QuestraColors.gold,
            ),
            label: AnimatedSwitcher(
              duration: settings.reduceScreenMotion(
                osReduceMotion: MediaQuery.disableAnimationsOf(context),
              )
                  ? Duration.zero
                  : QuestraMotion.fast,
              switchInCurve: QuestraMotion.standard,
              switchOutCurve: QuestraMotion.standard,
              child: Text(
                key: ValueKey(mission.status),
                canComplete ? 'Missionを完了' : '完了済み',
              ),
            ),
          ),
        ],
      ),
    );

    if (!settings.swipeGesturesEnabled || !canComplete) return card;
    return Dismissible(
      key: ValueKey('mission-swipe-${mission.id}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.55},
      confirmDismiss: (_) async {
        _completeMission(
          context,
          ref,
          mission,
          source: _MissionCompletionSource.swipe,
        );
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: QuestraColors.cosmicBlue.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: QuestraColors.gold),
            SizedBox(width: 8),
            Text(
              '完了',
              style: TextStyle(
                color: QuestraColors.gold,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      child: card,
    );
  }
}

class _MissionSignalPanel extends StatelessWidget {
  const _MissionSignalPanel({required this.signals});

  final List<MissionSignal> signals;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Signal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Arcが今のMission状況から、やさしく次の一歩を照らします。'),
          const SizedBox(height: 12),
          ...signals.map(
            (signal) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MissionSignalTile(signal: signal),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionSignalTile extends StatelessWidget {
  const _MissionSignalTile({required this.signal});

  final MissionSignal signal;

  @override
  Widget build(BuildContext context) {
    final color = switch (signal.severity) {
      MissionSignalSeverity.urgent => QuestraColors.gold,
      MissionSignalSeverity.focus => QuestraColors.cosmicBlue,
      MissionSignalSeverity.calm => QuestraColors.slate,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
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

enum _MissionCompletionSource { button, swipe }

void _completeMission(
  BuildContext context,
  WidgetRef ref,
  Mission mission, {
  required _MissionCompletionSource source,
}) {
  final completedMission =
      ref.read(missionControllerProvider.notifier).completeMission(mission.id);
  if (completedMission == null) {
    final settings = ref.read(experienceSettingsControllerProvider);
    unawaited(
      ref.read(hapticFeedbackServiceProvider).trigger(
            QuestraHapticCue.error,
            settings: settings,
          ),
    );
    return;
  }
  final settings = ref.read(experienceSettingsControllerProvider);
  unawaited(
    ref.read(hapticFeedbackServiceProvider).trigger(
          QuestraHapticCue.success,
          settings: settings,
        ),
  );
  unawaited(
    ref.read(soundEffectServiceProvider).play(
          QuestraSoundEffect.missionComplete,
          settings: settings,
        ),
  );
  unawaited(
    ref
        .read(arcMotionControllerProvider.notifier)
        .react(ArcAnimationState.cheering),
  );
  unawaited(
    ref.read(analyticsServiceProvider).track(
          AnalyticsEvent(
            name: source == _MissionCompletionSource.swipe
                ? AnalyticsEventName.missionCompletedBySwipe
                : AnalyticsEventName.missionCompletedByButton,
            properties: {'source': source.name},
          ),
        ),
  );
  showArcCelebrationSnackBar(
    context,
    ref.read(arcCelebrationServiceProvider).build(
          event: ArcCelebrationEvent.missionCompleted,
          subject: completedMission.title,
        ),
  );
}
