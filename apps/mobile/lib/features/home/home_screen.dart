import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../arc/arc_action_trigger_service.dart';
import '../arc/arc_daily_greeting_service.dart';
import '../arc/arc_emotion_timeline_controller.dart';
import '../arc/arc_emotion_timeline_model.dart';
import '../arc/arc_guidance_providers.dart';
import '../arc/navigator_rank_service.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../challenge_graph/challenge_graph_preview_service.dart';
import '../horizon/horizon_next_challenge_service.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_model.dart';
import '../signal/mission_signal_model.dart';
import '../signal/signal_providers.dart';
import '../star_map/star_map_recommendation_service.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_highlight_service.dart';
import '../trail/trail_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final quests = ref.watch(questControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    final trails = ref.watch(trailControllerProvider);
    final emotionEvents = ref.watch(arcEmotionTimelineControllerProvider);
    final latestEvent = emotionEvents.firstOrNull;
    final inactiveDecision = ref
        .watch(arcActionTriggerServiceProvider)
        .resolve(trigger: ArcActionTrigger.inactiveConcern);
    final missionSignals = ref
        .watch(missionSignalServiceProvider)
        .generate(
          quests: quests,
          missions: missions,
          now: DateTime.now(),
          signalFrequency: profile?.signalFrequency ?? SignalFrequency.balanced,
        );
    final trailHighlights = const TrailHighlightService().rank(
      trails: trails,
      attachments: const {},
    );
    final graphInsights = quests
        .where((quest) => quest.status == QuestStatus.active)
        .expand(
          (quest) => const ChallengeGraphPreviewService().insightsForQuest(
            quest: quest,
            missions: missions,
            trails: trails,
          ),
        )
        .toList(growable: false);
    final starMapRecommendations = const StarMapRecommendationService()
        .recommend(
          quests: quests,
          missions: missions,
          trails: trails,
          highlights: trailHighlights,
          graphInsights: graphInsights,
        );
    final navigatorRank = ref
        .watch(navigatorRankServiceProvider)
        .resolve(
          quests: quests,
          missions: missions,
          trails: trails,
          bondScore: profile?.bondScore ?? 0,
          stardustBalance: profile?.stardustBalance ?? 0,
        );
    final horizonChallenge = const HorizonNextChallengeService().suggest(
      rank: navigatorRank,
      quests: quests,
      missions: missions,
      trails: trails,
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
    final todayMission = missions
        .where((mission) => mission.status == MissionStatus.todo)
        .firstOrNull;
    final recentTrails = trails.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final visibleRecentTrails = recentTrails.take(2).toList(growable: false);
    final guildContextCount =
        activeQuests.length +
        visibleRecentTrails.length +
        missionSignals.length;

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.adventure),
        child: SafeArea(
          child: QuestraResponsiveListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              const _CaptainStatusBar(),
              const SizedBox(height: AppSpacing.lg),
              _ArcHero(greeting: greeting),
              const SizedBox(height: AppSpacing.md),
              _JourneyFlowCard(
                activeQuest: activeQuests.firstOrNull,
                mission: todayMission,
                onOpenArc: () => context.go(AppRoutes.arc),
                onOpenQuest: () => context.go(AppRoutes.quest),
                onCreateQuest: () => context.go('${AppRoutes.quest}/create'),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ArcSignalCard(
                emotion: latestEvent?.emotion ?? inactiveDecision.emotion,
                label: latestEvent?.sourceType.label ?? 'Arc Signal',
                message: latestEvent?.reason ?? inactiveDecision.message,
              ),
              if (missionSignals.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _MissionSignalCard(signal: missionSignals.first),
              ],
              const SizedBox(height: AppSpacing.xl),
              _HomeSectionHeader(
                title: '今日のMission',
                actionLabel: 'Missionへ',
                onAction: () => context.go(AppRoutes.mission),
              ),
              const SizedBox(height: AppSpacing.md),
              _TodayMissionCard(
                mission: todayMission,
                onOpenMission: () => context.go(AppRoutes.mission),
                onCreateQuest: () => context.go('${AppRoutes.quest}/create'),
              ),
              const SizedBox(height: AppSpacing.xl),
              _HomeSectionHeader(
                title: '進行中のQuest',
                actionLabel: 'すべて見る',
                onAction: () => context.go(AppRoutes.quest),
              ),
              const SizedBox(height: AppSpacing.md),
              if (activeQuests.isEmpty)
                _HomeEmptyActionCard(
                  icon: Icons.flag_outlined,
                  title: 'まだ進行中のQuestはありません',
                  message: '最初のQuestを灯すと、ArcがMissionとTrailへの航路を一緒に描きます。',
                  actionLabel: '新しいQuestを始める',
                  onAction: () => context.go('${AppRoutes.quest}/create'),
                )
              else
                ...activeQuests
                    .take(2)
                    .map(
                      (quest) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _ActiveQuestCard(
                          quest: quest,
                          onTap: () =>
                              context.go('${AppRoutes.quest}/${quest.id}'),
                        ),
                      ),
                    ),
              const SizedBox(height: AppSpacing.lg),
              _HomeSectionHeader(
                title: '最近のTrail',
                actionLabel: 'Trailへ',
                onAction: () => context.go(AppRoutes.trail),
              ),
              const SizedBox(height: AppSpacing.md),
              _RecentTrailsCard(
                trails: visibleRecentTrails,
                onOpenTrail: () => context.go(AppRoutes.trail),
              ),
              const SizedBox(height: AppSpacing.lg),
              _GuildActivitySummary(
                contextCount: guildContextCount,
                onOpenGuild: () => context.go(AppRoutes.guild),
              ),
              const SizedBox(height: AppSpacing.xl),
              _StarMapPreview(
                recommendation: starMapRecommendations.firstOrNull,
              ),
              const SizedBox(height: AppSpacing.lg),
              _HorizonChallengeCard(challenge: horizonChallenge),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizonChallengeCard extends StatelessWidget {
  const _HorizonChallengeCard({required this.challenge});

  final HorizonNextChallenge challenge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.74),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.22)),
        boxShadow: AppShadows.glassCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.public, color: AppColors.gold, size: 34),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.readinessLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  challenge.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  challenge.reason,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchment,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  challenge.suggestedAction,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.skyBlue,
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

class _ActiveQuestCard extends StatelessWidget {
  const _ActiveQuestCard({required this.quest, required this.onTap});

  final Quest quest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (quest.progress * 100).round().clamp(0, 100);

    return Semantics(
      button: true,
      label: '${quest.title}のQuestを開く',
      value: '進捗$progressPercentパーセント',
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
              const SizedBox(height: AppSpacing.sm),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: quest.progress.clamp(0, 1),
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
                    '$progressPercent%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w900,
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
    return _HomeGlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchment,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.add),
                    label: Text(actionLabel),
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
