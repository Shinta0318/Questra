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
import '../arc/arc_action_trigger_service.dart';
import '../arc/arc_daily_greeting_service.dart';
import '../arc/arc_emotion_timeline_controller.dart';
import '../arc/arc_emotion_timeline_model.dart';
import '../arc/arc_guidance_providers.dart';
import '../auth/auth_controller.dart';
import '../mission/mission_controller.dart';
import '../quest/quest_controller.dart';
import '../signal/mission_signal_model.dart';
import '../signal/signal_providers.dart';
import '../star_map/star_map_recommendation_service.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_highlight_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _quests = [
    _HomeQuest('Questraをローンチする', 0.42, '起業', 3),
    _HomeQuest('英語を話せるようになる', 0.18, '学習', 2),
    _HomeQuest('富士山に登る', 0.67, '挑戦', 3),
  ];

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
        .generate(quests: quests, missions: missions, now: DateTime.now());
    final trailHighlights = const TrailHighlightService().rank(
      trails: trails,
      attachments: const {},
    );
    final starMapRecommendations = const StarMapRecommendationService()
        .recommend(
          quests: quests,
          missions: missions,
          trails: trails,
          highlights: trailHighlights,
        );
    final greeting = ref
        .watch(arcDailyGreetingServiceProvider)
        .resolve(
          quests: quests,
          missions: missions,
          trails: trails,
          now: DateTime.now(),
          nickname: profile?.nickname,
        );

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.adventure),
        child: SafeArea(
          child: ListView(
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
              Row(
                children: [
                  Text(
                    '進行中のQuest',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: AppColors.white),
                  ),
                  const Spacer(),
                  Text(
                    'すべて見る',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warmGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ..._quests.map(
                (quest) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _QuestMockCard(quest: quest),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () => context.go('${AppRoutes.quest}/create'),
                icon: const Icon(Icons.add),
                label: const Text('新しいQuestを始める'),
              ),
              const SizedBox(height: AppSpacing.xl),
              _StarMapPreview(
                recommendation: starMapRecommendations.firstOrNull,
              ),
            ],
          ),
        ),
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
    return Row(
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
        const Spacer(),
        const _MetricPill(icon: Icons.monetization_on, label: '2,450'),
        const SizedBox(width: AppSpacing.sm),
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

class _QuestMockCard extends StatelessWidget {
  const _QuestMockCard({required this.quest});

  final _HomeQuest quest;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (quest.progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.78),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.24)),
        boxShadow: AppShadows.glassCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quest.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: quest.progress,
              minHeight: 8,
              backgroundColor: AppColors.deepNavy,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _QuestTag(label: quest.category),
              const Spacer(),
              Text(
                '$progressPercent%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '進行中',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.parchment,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < quest.stars ? Icons.star : Icons.star_border,
                size: 16,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
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
                      ? 'Quest、Mission、Trailをつないで次の航路を見つけよう。'
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

class _HomeQuest {
  const _HomeQuest(this.title, this.progress, this.category, this.stars);

  final String title;
  final double progress;
  final String category;
  final int stars;
}
