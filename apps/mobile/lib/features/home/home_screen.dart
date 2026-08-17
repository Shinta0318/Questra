import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/performance/grouped_collection_index.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_approved_portrait.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/layout/questra_screen_surface.dart';
import '../arc/arc_daily_greeting_service.dart';
import '../arc/navigator_rank_service.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../horizon/horizon_next_challenge_service.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../mission/today_best_next_mission_service.dart';
import '../mission/today_mission_preference_controller.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_model.dart';
import '../quest/planning_preferences_controller.dart';
import '../quest/weekly_availability.dart';
import '../quest/quest_progress_service.dart';
import '../quest_journey/quest_journey_contract.dart';
import '../signal/mission_signal_model.dart';
import '../signal/signal_providers.dart';
import '../signal/task_signal_card.dart';
import '../star_map/star_map_recommendation_service.dart';
import '../trail/trail_model.dart';
import '../trail/trail_controller.dart';
import '../task/task_controller.dart';
import '../task/task_availability_service.dart';
import '../task/task_model.dart';
import '../task/task_load_state.dart';
import 'home_today_task_journey.dart';
import 'widgets/home_horizon_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final quests = ref.watch(questControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    final tasks = ref.watch(taskControllerProvider);
    final taskLoadState = ref.watch(taskLoadStateProvider);
    final todayTask = ref.read(taskControllerProvider.notifier).todaysTask;
    final planningPreferences = ref.watch(
      planningPreferencesControllerProvider,
    );
    final todayPreference = ref.watch(todayMissionPreferenceControllerProvider);
    final trails = ref.watch(trailControllerProvider);
    final navigatorRank = ref
        .watch(navigatorRankServiceProvider)
        .resolve(stardustBalance: profile?.stardustBalance ?? 0);
    final greeting = ref.watch(arcDailyGreetingServiceProvider).resolve(
          quests: quests,
          missions: missions,
          trails: trails,
          now: DateTime.now(),
          nickname: profile?.nickname,
          arcName: profile?.arcName,
          questInterest: profile?.questInterest ?? QuestInterest.adventure,
        );
    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    final today = WeekdayLabel.fromDateTime(DateTime.now());
    final todayMinutes = planningPreferences.context.consentGranted
        ? planningPreferences.availability.minutesFor(today)
        : null;
    final now = DateTime.now();
    final activeTodayPreference = todayPreference.isFor(now)
        ? todayPreference
        : const TodayMissionPreference();
    final todayRecommendation = activeTodayPreference.isResting
        ? null
        : TodayBestNextMissionService.recommend(
            missions,
            availableMinutes: todayMinutes,
            excludedMissionIds: activeTodayPreference.excludedMissionIds,
            fiveMinuteMissionId: activeTodayPreference.fiveMinuteMissionId,
          );
    final todayMissions = todayRecommendation == null
        ? const <Mission>[]
        : <Mission>[todayRecommendation.mission];
    final todayJourney = const HomeTodayTaskJourneyService().resolve(
      tasks: tasks,
      loadState: taskLoadState,
      now: now,
      recommendedTask: todayTask,
      hasActiveJourney: activeQuests.isNotEmpty || missions.isNotEmpty,
      isSignedIn: profile != null,
    );
    final focusTasks = const QuestFocusSelectionService().select(
      tasks: tasks,
      missions: missions,
    );
    final additionalFocusTasks = focusTasks
        .where((task) => task.id != todayJourney.task?.id)
        .take(2)
        .toList(growable: false);
    final taskSignals = ref.watch(taskSignalServiceProvider).generate(
          tasks: tasks,
          now: now,
          frequency: profile?.signalFrequency ?? SignalFrequency.balanced,
        );
    final missionsByQuest = GroupedCollectionIndex<String, Mission>.build(
      missions,
      keyOf: (mission) => mission.questId,
    );
    final questItems = activeQuests
        .take(3)
        .map(
          (quest) => _HomeQuestItem(
            quest: quest,
            progress: const QuestProgressService().calculate(
              missionsByQuest.valuesFor(quest.id),
            ),
            nextMission: missionsByQuest
                .valuesFor(quest.id)
                .where((mission) => mission.status == MissionStatus.todo)
                .firstOrNull,
          ),
        )
        .toList(growable: false);
    final horizon = const HorizonNextChallengeService().suggest(
      rank: navigatorRank,
      quests: quests,
      missions: missions,
      trails: trails,
    );

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: QuestraScreenSurface(
        child: QuestraResponsiveListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            120,
          ),
          children: [
            _SimplifiedArcHero(
              message: greeting.message,
              onOpenArc: () => context.go(AppRoutes.arc),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SimpleSectionTitle(title: '今日のTask'),
            const SizedBox(height: AppSpacing.md),
            _HomeTodayTaskCard(
              journey: todayJourney,
              additionalTasks: additionalFocusTasks,
              suggestedMission: todayMissions.firstOrNull,
              recommendationReason: todayRecommendation?.reason,
              isResting: activeTodayPreference.isResting,
              onOpenTask: (task) => context.push(
                AppRoutes.questJourneyFocus(
                  questId: task.questId,
                  missionId: task.missionId,
                  taskId: task.id,
                ),
              ),
              onStartTask: (task) async {
                final started = await ref
                    .read(taskControllerProvider.notifier)
                    .start(task.id);
                if (started && context.mounted) {
                  context.push(
                    AppRoutes.questJourneyFocus(
                      questId: task.questId,
                      missionId: task.missionId,
                      taskId: task.id,
                    ),
                  );
                }
              },
              onOpenMission: (questId, missionId) =>
                  context.push(AppRoutes.missionDetail(questId, missionId)),
              onOpenArc: () => context.go(AppRoutes.arc),
              onOpenTrail: () => context.go(AppRoutes.trail),
              onRetry: () => ref.read(taskControllerProvider.notifier).reload(),
              onResume: () => ref
                  .read(todayMissionPreferenceControllerProvider.notifier)
                  .resumeToday(),
            ),
            if (taskSignals.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              TaskSignalCard(
                signal: taskSignals.first,
                onOpen: () {
                  final signal = taskSignals.first;
                  context.push(
                    AppRoutes.taskDetail(
                      signal.questId,
                      signal.missionId,
                      signal.taskId,
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const _SimpleSectionTitle(title: '進行中のQuest'),
            const SizedBox(height: AppSpacing.md),
            if (activeQuests.isEmpty)
              _HomeEmptyActionCard(
                icon: Icons.flag_outlined,
                title: 'まだ進行中のQuestはありません',
                message: 'Arcに叶えたいことを話して、最初のQuestを見つけましょう。',
                actionLabel: 'Arcに話す',
                onAction: () => context.go(AppRoutes.arc),
              )
            else
              _HomeQuestDeck(
                items: questItems,
                onOpen: (quest) => context.go('${AppRoutes.quest}/${quest.id}'),
              ),
            const SizedBox(height: AppSpacing.xl),
            const _SimpleSectionTitle(title: '最近のTrail'),
            const SizedBox(height: AppSpacing.md),
            _RecentTrailsCard(
              trails: trails.take(3).toList(growable: false),
              onOpenTrail: () => context.go(AppRoutes.trail),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SimpleSectionTitle(title: '次の航路'),
            const SizedBox(height: AppSpacing.md),
            HomeHorizonCard(
              challenge: horizon,
              onAction: () {
                switch (horizon.destination) {
                  case HorizonDestination.arc:
                    context.go(AppRoutes.arc);
                  case HorizonDestination.mission:
                    final questId = horizon.questId;
                    final missionId = horizon.missionId;
                    if (questId != null && missionId != null) {
                      context.push(AppRoutes.missionDetail(questId, missionId));
                    }
                  case HorizonDestination.trail:
                    context.go(AppRoutes.trail);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Kept for the post-simplification Signal phase.
// ignore: unused_element
class _MissionSignalCard extends StatelessWidget {
  const _MissionSignalCard({required this.signal});

  final MissionSignal signal;

  @override
  Widget build(BuildContext context) {
    final color = switch (signal.severity) {
      MissionSignalSeverity.urgent => AppColors.gold,
      MissionSignalSeverity.focus => AppColors.skyBlue,
      MissionSignalSeverity.calm => AppColors.parchment,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.68),
        borderRadius: AppRadius.card,
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: AppShadows.glassCard,
      ),
      child: Row(
        children: [
          Icon(Icons.wb_twilight_outlined, color: color, size: 30),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.severity.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  signal.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  signal.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.parchment,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Kept for the post-simplification Arc signal phase.
// ignore: unused_element
class _ArcSignalCard extends StatelessWidget {
  const _ArcSignalCard({
    required this.emotion,
    required this.label,
    required this.message,
  });

  final ArcEmotion emotion;
  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.70),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
        boxShadow: AppShadows.goldGlow,
      ),
      child: Row(
        children: [
          ArcWidget(emotion: emotion, size: 58, showSpeechBubble: false),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.white,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Kept for the post-simplification progression phase.
// ignore: unused_element
class _CaptainStatusBar extends StatelessWidget {
  const _CaptainStatusBar();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ArcWidget(
                emotion: ArcEmotion.normal,
                size: 36,
                showSpeechBubble: false,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'キャプテン\nLv.24',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
              ),
            ],
          ),
        ),
        const _MetricPill(icon: Icons.monetization_on, label: '2,450'),
        const _MetricPill(icon: Icons.auto_awesome, label: '18'),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.cosmicBlue.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _SimplifiedArcHero extends StatelessWidget {
  const _SimplifiedArcHero({required this.message, required this.onOpenArc});

  final String message;
  final VoidCallback onOpenArc;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Arcに話す',
      child: InkWell(
        borderRadius: AppRadius.glassCard,
        onTap: () {
          HapticFeedback.selectionClick();
          onOpenArc();
        },
        child: _HomeGlassCard(
          child: Row(
            children: [
              const ArcApprovedPortrait(size: 92),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arc',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'タップして話す',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.parchment,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleSectionTitle extends StatelessWidget {
  const _SimpleSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

class _HomeTodayTaskCard extends ConsumerWidget {
  const _HomeTodayTaskCard({
    required this.journey,
    required this.additionalTasks,
    required this.suggestedMission,
    required this.recommendationReason,
    required this.isResting,
    required this.onOpenTask,
    required this.onStartTask,
    required this.onOpenMission,
    required this.onOpenArc,
    required this.onOpenTrail,
    required this.onRetry,
    required this.onResume,
  });

  final HomeTodayTaskJourney journey;
  final List<QuestraTask> additionalTasks;
  final Mission? suggestedMission;
  final String? recommendationReason;
  final bool isResting;
  final ValueChanged<QuestraTask> onOpenTask;
  final ValueChanged<QuestraTask> onStartTask;
  final void Function(String questId, String missionId) onOpenMission;
  final VoidCallback onOpenArc;
  final VoidCallback onOpenTrail;
  final VoidCallback onRetry;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (journey.status == HomeTodayTaskStatus.loading) {
      return const _HomeTaskStateCard(
        icon: Icons.auto_awesome,
        title: '今日の一歩を探しています',
        message: 'Arcが現在の航路を確認しています。',
        showProgress: true,
      );
    }
    if (journey.status == HomeTodayTaskStatus.failed) {
      return _HomeTaskStateCard(
        icon: Icons.cloud_off_outlined,
        title: '今日のTaskを読み込めませんでした',
        message: '入力内容は失われていません。通信を確認して、もう一度お試しください。',
        actionLabel: 'もう一度読み込む',
        onAction: onRetry,
      );
    }
    if (journey.status == HomeTodayTaskStatus.completed) {
      return _HomeTaskStateCard(
        icon: Icons.check_circle_outline_rounded,
        title: '今日の一歩を進めました',
        message: '${journey.task!.title}を完了しました。この瞬間をTrailに残せます。',
        contextLabel: _parentContext(journey.task!),
        actionLabel: 'Trailに残す',
        onAction: onOpenTrail,
      );
    }
    if (journey.status == HomeTodayTaskStatus.empty) {
      if (isResting) {
        return _HomeTaskStateCard(
          icon: Icons.bedtime_outlined,
          title: '今日は休む日',
          message: '休むことも航路の一部です。明日の一歩へ備えましょう。',
          actionLabel: 'やっぱり進める',
          onAction: onResume,
        );
      }
      final mission = suggestedMission;
      return _HomeTaskStateCard(
        icon: Icons.route_outlined,
        title: mission == null ? '今日の航路はまだ自由です' : '次のTaskを整えましょう',
        message: mission == null
            ? 'Arcと話して、いまの自分に合う小さな一歩を見つけられます。'
            : recommendationReason ?? 'Missionを開いて、実行できるTaskを確認しましょう。',
        contextLabel: mission == null
            ? null
            : '${mission.questTitle}  /  ${mission.title}',
        actionLabel: mission == null ? 'Arcに相談する' : 'Missionを確認する',
        onAction: mission == null
            ? onOpenArc
            : () => onOpenMission(mission.questId, mission.id),
      );
    }

    final task = journey.task!;
    final missionTasks = ref
        .watch(taskControllerProvider)
        .where((item) => item.missionId == task.missionId);
    final availability = const TaskAvailabilityService().evaluate(
      task,
      missionTasks,
    );
    final canStart = availability.canStart;
    final actionLabel = canStart ? 'このTaskを始める' : 'Taskを開く';
    return Semantics(
      container: true,
      label: '今日のTask、${task.title}。${_parentContext(task)}',
      child: _HomeGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _parentContext(task),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.skyBlue,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              task.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              task.action,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.parchment,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _QuestTag(label: task.status.label),
                if (task.estimatedEffortMinutes != null)
                  _QuestTag(label: '約${task.estimatedEffortMinutes}分'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => canStart
                    ? onStartTask(task)
                    : availability.isDependencyBlocked
                        ? onOpenMission(task.questId, task.missionId)
                        : onOpenTask(task),
                icon: Icon(
                  canStart ? Icons.play_arrow_rounded : Icons.arrow_forward,
                ),
                label: Text(
                  availability.isDependencyBlocked
                      ? '前提Taskを確認する'
                      : actionLabel,
                ),
              ),
            ),
            if (additionalTasks.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(color: Colors.white12),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'このあと',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.parchment,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              for (final next in additionalTasks)
                ListTile(
                  minTileHeight: 48,
                  contentPadding: EdgeInsets.zero,
                  onTap: () => onOpenTask(next),
                  leading: const Icon(
                    Icons.circle_outlined,
                    color: AppColors.skyBlue,
                    size: 20,
                  ),
                  title: Text(
                    next.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.white),
                  ),
                  subtitle: Text(
                    _parentContext(next),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.parchment),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _parentContext(QuestraTask task) {
    final quest = task.questTitle.isEmpty ? 'Quest' : task.questTitle;
    final mission = task.missionTitle.isEmpty ? 'Mission' : task.missionTitle;
    return '$quest  /  $mission';
  }
}

class _HomeTaskStateCard extends StatelessWidget {
  const _HomeTaskStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.contextLabel,
    this.actionLabel,
    this.onAction,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? contextLabel;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: showProgress,
      label: '$title。$message',
      child: _HomeGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.gold, size: 30),
            if (contextLabel != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                contextLabel!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.skyBlue,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchment,
                    height: 1.45,
                  ),
            ),
            if (showProgress) ...[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Kept as the richer Home hero variant for a later phase.
// ignore: unused_element
class _ArcHero extends StatelessWidget {
  const _ArcHero({required this.greeting});

  final ArcDailyGreeting greeting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.72),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.22)),
        boxShadow: AppShadows.glassCard,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuestTag(label: greeting.contextLabel),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  greeting.message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        height: 1.55,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          ArcWidget(
            emotion: greeting.emotion,
            size: 120,
            showSpeechBubble: false,
          ),
        ],
      ),
    );
  }
}

// Kept for secondary Home sections after the center flow is stable.
// ignore: unused_element
class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

// Kept for a later journey overview phase.
// ignore: unused_element
class _JourneyFlowCard extends StatelessWidget {
  const _JourneyFlowCard({
    required this.activeQuest,
    required this.mission,
    required this.onOpenArc,
    required this.onOpenQuest,
    required this.onCreateQuest,
  });

  final Quest? activeQuest;
  final Mission? mission;
  final VoidCallback onOpenArc;
  final VoidCallback onOpenQuest;
  final VoidCallback onCreateQuest;

  @override
  Widget build(BuildContext context) {
    final progress = ((activeQuest?.progress ?? 0) * 100).round().clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.white.withValues(alpha: 0.14),
            AppColors.cosmicBlue.withValues(alpha: 0.20),
            AppColors.gold.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.white.withValues(alpha: 0.18)),
        boxShadow: AppShadows.glassCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Home → Arc → Quest',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Arcと一緒に今日の一歩を進める',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _FlowStepPill(
                icon: Icons.home_outlined,
                label: '現在地',
                value: mission?.title ?? '優先Missionを準備中',
              ),
              _FlowStepPill(
                icon: Icons.auto_awesome,
                label: 'Arc',
                value: '次の航路を相談',
              ),
              _FlowStepPill(
                icon: Icons.explore_outlined,
                label: 'Quest',
                value: activeQuest == null ? '新しい挑戦へ' : '$progress%進行中',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: onOpenArc,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Arcに相談する'),
              ),
              OutlinedButton.icon(
                onPressed: activeQuest == null ? onCreateQuest : onOpenQuest,
                icon: const Icon(Icons.explore_outlined),
                label: Text(activeQuest == null ? '新しいQuestを始める' : 'Questを見る'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowStepPill extends StatelessWidget {
  const _FlowStepPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.deepNavy.withValues(alpha: 0.44),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.parchment,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Kept as a detailed single-Mission variant.
// ignore: unused_element
class _TodayMissionCard extends StatelessWidget {
  const _TodayMissionCard({
    required this.mission,
    required this.onOpenMission,
    required this.onCreateQuest,
  });

  final Mission? mission;
  final VoidCallback onOpenMission;
  final VoidCallback onCreateQuest;

  @override
  Widget build(BuildContext context) {
    if (mission == null) {
      return _HomeEmptyActionCard(
        icon: Icons.task_alt_outlined,
        title: '優先Missionはまだありません',
        message: 'Questを作ると、Arcが最初の小さなMission候補を一緒に描きます。',
        actionLabel: 'Questから始める',
        onAction: onCreateQuest,
      );
    }

    return _HomeGlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HomeIconBadge(icon: Icons.bolt_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuestTag(label: mission!.questTitle),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  mission!.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  mission!.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.parchment,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onOpenMission,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Missionを進める'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeQuestItem {
  const _HomeQuestItem({
    required this.quest,
    required this.progress,
    required this.nextMission,
  });

  final Quest quest;
  final QuestProgressSnapshot progress;
  final Mission? nextMission;
}

class _HomeQuestDeck extends StatefulWidget {
  const _HomeQuestDeck({required this.items, required this.onOpen});

  final List<_HomeQuestItem> items;
  final ValueChanged<Quest> onOpen;

  @override
  State<_HomeQuestDeck> createState() => _HomeQuestDeckState();
}

class _HomeQuestDeckState extends State<_HomeQuestDeck> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Column(
            children: [
              for (final item in widget.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _questCard(item),
                ),
            ],
          );
        }

        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compactTextAllowance =
            ((500 - constraints.maxWidth) * 0.9).clamp(0, 160).toDouble();
        final deckHeight =
            178 + compactTextAllowance * (textScale - 1).clamp(0, 1);
        return Column(
          children: [
            SizedBox(
              height: deckHeight,
              child: PageView.builder(
                controller: _controller,
                padEnds: false,
                itemCount: widget.items.length,
                onPageChanged: (page) {
                  HapticFeedback.selectionClick();
                  setState(() => _page = page);
                },
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: _questCard(widget.items[index]),
                ),
              ),
            ),
            if (widget.items.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < widget.items.length; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == _page ? 20 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? AppColors.gold
                            : AppColors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _questCard(_HomeQuestItem item) {
    return _ActiveQuestCard(
      quest: item.quest,
      progress: item.progress,
      nextMission: item.nextMission,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onOpen(item.quest);
      },
    );
  }
}

class _ActiveQuestCard extends StatelessWidget {
  const _ActiveQuestCard({
    required this.quest,
    required this.progress,
    required this.nextMission,
    required this.onTap,
  });

  final Quest quest;
  final QuestProgressSnapshot progress;
  final Mission? nextMission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${quest.title}のQuestを開く',
      value: '進捗${progress.percent}パーセント、Mission ${progress.missionCountLabel}',
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: _HomeGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quest.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (nextMission != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '次のMission: ${nextMission!.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.parchment,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress.value,
                    minHeight: 8,
                    backgroundColor: AppColors.deepNavy,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _QuestTag(label: quest.category),
                  _QuestTag(label: quest.difficulty.label),
                  Text(
                    '${progress.percent}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(
                    'Mission ${progress.missionCountLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.parchment,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTrailsCard extends StatelessWidget {
  const _RecentTrailsCard({required this.trails, required this.onOpenTrail});

  final List<Trail> trails;
  final VoidCallback onOpenTrail;

  @override
  Widget build(BuildContext context) {
    if (trails.isEmpty) {
      return _HomeEmptyActionCard(
        icon: Icons.timeline_outlined,
        title: 'まだRecent Trailはありません',
        message: 'Missionのあとに短く残すだけで、挑戦の航跡が見返せるようになります。',
        actionLabel: 'Trailを残す',
        onAction: onOpenTrail,
      );
    }

    return _HomeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final trail in trails) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_stories_outlined, color: AppColors.gold),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trail.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trail.summary,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.parchment,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trail.trailType.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.skyBlue,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (trail != trails.last)
              Divider(color: AppColors.white.withValues(alpha: 0.12)),
          ],
        ],
      ),
    );
  }
}

// Kept for the post-simplification Guild phase.
// ignore: unused_element
class _GuildActivitySummary extends StatelessWidget {
  const _GuildActivitySummary({
    required this.contextCount,
    required this.onOpenGuild,
  });

  final int contextCount;
  final VoidCallback onOpenGuild;

  @override
  Widget build(BuildContext context) {
    final hasContext = contextCount > 0;

    return _HomeGlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HomeIconBadge(icon: Icons.groups_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guildの動き',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasContext
                      ? 'Quest、Mission、Task、TrailからGuildへ持ち寄れる相談の種が$countText件あります。'
                      : 'QuestやTrailが増えると、Guildで相談しやすい問いがここに浮かびます。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.parchment,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onOpenGuild,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Guildを開く'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get countText => contextCount.toString();
}

class _HomeEmptyActionCard extends StatelessWidget {
  const _HomeEmptyActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: actionLabel,
      child: InkWell(
        borderRadius: AppRadius.glassCard,
        onTap: () {
          HapticFeedback.selectionClick();
          onAction();
        },
        child: _HomeGlassCard(
          child: Row(
            children: [
              _HomeIconBadge(icon: icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.parchment,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeIconBadge extends StatelessWidget {
  const _HomeIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold.withValues(alpha: 0.16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, color: AppColors.gold),
    );
  }
}

class _HomeGlassCard extends StatelessWidget {
  const _HomeGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.76),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.24)),
        boxShadow: AppShadows.glassCard,
      ),
      child: child,
    );
  }
}

class _QuestTag extends StatelessWidget {
  const _QuestTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cosmicBlue.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

// Kept for the post-simplification Star Map phase.
// ignore: unused_element
class _StarMapPreview extends StatelessWidget {
  const _StarMapPreview({required this.recommendation});

  final StarMapRecommendation? recommendation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.glass,
        borderRadius: AppRadius.glassCard,
        boxShadow: AppShadows.glassCard,
      ),
      child: Row(
        children: [
          const Icon(Icons.explore, color: AppColors.gold, size: 34),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Star Map',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.deepNavy,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation == null
                      ? 'Quest、Mission、Task、Trailをつないで、次の一歩を見つけよう。'
                      : recommendation!.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.deepNavy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (recommendation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    recommendation!.reason,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.midnightNavy,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
