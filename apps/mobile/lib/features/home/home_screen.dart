import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/experience/experience_settings_controller.dart';
import '../../core/experience/haptic_feedback_service.dart';
import '../../core/experience/sound_effect_service.dart';
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
import '../arc/arc_motion_controller.dart';
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
import '../signal/mission_signal_model.dart';
import '../star_map/star_map_recommendation_service.dart';
import '../trail/trail_model.dart';
import '../trail/trail_controller.dart';
import '../task/task_controller.dart';
import '../task/task_model.dart';
import 'widgets/home_horizon_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final quests = ref.watch(questControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    ref.watch(taskControllerProvider);
    final todayTask = ref.read(taskControllerProvider.notifier).todaysTask;
    final planningPreferences = ref.watch(
      planningPreferencesControllerProvider,
    );
    final todayPreference = ref.watch(todayMissionPreferenceControllerProvider);
    final trails = ref.watch(trailControllerProvider);
    final navigatorRank = ref
        .watch(navigatorRankServiceProvider)
        .resolve(
          quests: quests,
          missions: missions,
          trails: trails,
          bondScore: profile?.bondScore ?? 0,
          stardustBalance: profile?.stardustBalance ?? 0,
        );
    final greeting = ref
        .watch(arcDailyGreetingServiceProvider)
        .resolve(
          quests: quests,
          missions: missions,
          trails: trails,
          now: DateTime.now(),
          nickname: profile?.nickname,
          arcName: profile?.arcName,
          questInterest: profile?.questInterest ?? QuestInterest.adventure,
        );
    final activeQuests =
        quests.where((quest) => quest.status == QuestStatus.active).toList()
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
    final questItems = activeQuests
        .take(3)
        .map(
          (quest) => _HomeQuestItem(
            quest: quest,
            progress: const QuestProgressService().calculate(
              missions.where((mission) => mission.questId == quest.id),
            ),
            nextMission: missions
                .where(
                  (mission) =>
                      mission.questId == quest.id &&
                      mission.status == MissionStatus.todo,
                )
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
            AppSpacing.xxl,
          ),
          children: [
            _SimplifiedArcHero(
              message: greeting.message,
              onOpenArc: () => context.go(AppRoutes.arc),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SimpleSectionTitle(title: '今日のTask'),
            const SizedBox(height: AppSpacing.md),
            if (todayTask != null)
              _HomeTaskCard(task: todayTask)
            else
              _HomeMissionList(
                missions: todayMissions,
                recommendationReason: todayRecommendation?.reason,
                onComplete: (mission) => ref
                    .read(missionControllerProvider.notifier)
                    .completeMission(mission.id),
                onOpenArc: () => context.go(AppRoutes.arc),
                isResting: activeTodayPreference.isResting,
                onChooseAnother: todayRecommendation == null
                    ? null
                    : () => ref
                          .read(
                            todayMissionPreferenceControllerProvider.notifier,
                          )
                          .chooseAnother(todayRecommendation.mission.id),
                onFiveMinutes: todayRecommendation == null
                    ? null
                    : () => ref
                          .read(
                            todayMissionPreferenceControllerProvider.notifier,
                          )
                          .useFiveMinutes(todayRecommendation.mission.id),
                onRest: () => ref
                    .read(todayMissionPreferenceControllerProvider.notifier)
                    .restToday(),
                onResume: () => ref
                    .read(todayMissionPreferenceControllerProvider.notifier)
                    .resumeToday(),
              ),
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
            HomeHorizonCard(challenge: horizon),
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

class _HomeTaskCard extends ConsumerWidget {
  const _HomeTaskCard({required this.task});

  final QuestraTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.38)),
        boxShadow: AppShadows.glassCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(task.action),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => context.go(
                    AppRoutes.missionDetail(task.questId, task.missionId),
                  ),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: Text(task.missionTitle),
                ),
              ),
              FilledButton.icon(
                onPressed: task.status == TaskStatus.completed
                    ? null
                    : () => ref
                          .read(taskControllerProvider.notifier)
                          .complete(task.id),
                icon: const Icon(Icons.check),
                label: const Text('完了'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeMissionList extends ConsumerWidget {
  const _HomeMissionList({
    required this.missions,
    required this.recommendationReason,
    required this.onComplete,
    required this.onOpenArc,
    required this.isResting,
    required this.onChooseAnother,
    required this.onFiveMinutes,
    required this.onRest,
    required this.onResume,
  });

  final List<Mission> missions;
  final String? recommendationReason;
  final ValueChanged<Mission> onComplete;
  final VoidCallback onOpenArc;
  final bool isResting;
  final VoidCallback? onChooseAnother;
  final VoidCallback? onFiveMinutes;
  final VoidCallback onRest;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (missions.isEmpty) {
      return _HomeEmptyActionCard(
        icon: Icons.task_alt_outlined,
        title: isResting ? '今日は休む日' : '今日はまだ自由です',
        message: isResting
            ? '休むことも航路の一部です。記録や評価にペナルティはありません。'
            : '話したいことがあれば、Arcと次の一歩を見つけられます。',
        actionLabel: isResting ? 'やっぱり進める' : 'Arcを開く',
        onAction: isResting ? onResume : onOpenArc,
      );
    }

    return _HomeGlassCard(
      child: Column(
        children: [
          if (recommendationReason != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                recommendationReason!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.skyBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          for (var index = 0; index < missions.length; index++) ...[
            if (ref
                .watch(experienceSettingsControllerProvider)
                .swipeGesturesEnabled)
              Dismissible(
                key: ValueKey('home-mission-${missions[index].id}'),
                direction: DismissDirection.startToEnd,
                dismissThresholds: const {DismissDirection.startToEnd: 0.55},
                confirmDismiss: (_) async {
                  _completeWithFeedback(ref, missions[index]);
                  return false;
                },
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.auroraTeal.withValues(alpha: 0.22),
                    borderRadius: AppRadius.card,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.auroraTeal,
                  ),
                ),
                child: _HomeMissionTile(
                  mission: missions[index],
                  onComplete: () => _completeWithFeedback(ref, missions[index]),
                ),
              )
            else
              _HomeMissionTile(
                mission: missions[index],
                onComplete: () => _completeWithFeedback(ref, missions[index]),
              ),
            if (index != missions.length - 1)
              Divider(color: AppColors.skyBlue.withValues(alpha: 0.18)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton.icon(
                onPressed: onChooseAnother,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('別のMission'),
              ),
              TextButton.icon(
                onPressed: onFiveMinutes,
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: const Text('5分だけ'),
              ),
              TextButton.icon(
                onPressed: onRest,
                icon: const Icon(Icons.bedtime_outlined, size: 18),
                label: const Text('今日は休む'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _completeWithFeedback(WidgetRef ref, Mission mission) {
    onComplete(mission);
    final settings = ref.read(experienceSettingsControllerProvider);
    unawaited(
      ref
          .read(hapticFeedbackServiceProvider)
          .trigger(QuestraHapticCue.success, settings: settings),
    );
    unawaited(
      ref
          .read(soundEffectServiceProvider)
          .play(QuestraSoundEffect.missionComplete, settings: settings),
    );
    unawaited(
      ref
          .read(arcMotionControllerProvider.notifier)
          .react(ArcAnimationState.cheering),
    );
  }
}

class _HomeMissionTile extends StatelessWidget {
  const _HomeMissionTile({required this.mission, required this.onComplete});

  final Mission mission;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: false,
          onChanged: (_) => onComplete(),
          semanticLabel: '${mission.title}を完了',
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mission.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                mission.questTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.skyBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
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
                value: mission?.title ?? '今日のMissionを準備中',
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
        title: '今日のMissionはまだありません',
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

        return Column(
          children: [
            SizedBox(
              height: 178,
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
                      ? 'Quest、Mission、TrailからGuildへ持ち寄れる相談の種が$countText件あります。'
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
                      ? 'Quest、Mission、Trailをつないで、次の一歩を見つけよう。'
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
