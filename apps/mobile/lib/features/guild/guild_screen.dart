import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/router/app_routes.dart';
import '../../core/performance/performance_limits.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/layout/questra_screen_surface.dart';
import '../../widgets/questra_card.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_model.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_model.dart';
import 'guild_quest_matching_service.dart';
import 'guild_safe_posting_review_service.dart';

final guildQuestMatchingServiceProvider = Provider<GuildQuestMatchingService>((
  ref,
) {
  return const GuildQuestMatchingService();
});

final guildSafePostingReviewServiceProvider =
    Provider<GuildSafePostingReviewService>((ref) {
      return const GuildSafePostingReviewService();
    });

class GuildScreen extends ConsumerWidget {
  const GuildScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(questControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    final trails = ref.watch(trailControllerProvider);
    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .toList();
    final openMissions = missions
        .where((mission) => mission.status == MissionStatus.todo)
        .take(QuestraPerformanceLimits.homeOpenMissionCount)
        .toList(growable: false);
    final latestTrails = trails
        .take(QuestraPerformanceLimits.guildTrailPreviewLimit)
        .toList(growable: false);
    final question = _buildGuildQuestion(activeQuests, openMissions);
    final postingReview = ref
        .watch(guildSafePostingReviewServiceProvider)
        .review(question);
    final guildMatches = activeQuests.isEmpty
        ? const <GuildQuestMatch>[]
        : ref
              .watch(guildQuestMatchingServiceProvider)
              .rank(sourceQuest: activeQuests.first, candidates: quests);
    final hasGuildContext =
        activeQuests.isNotEmpty ||
        openMissions.isNotEmpty ||
        latestTrails.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Guild')),
      body: QuestraScreenSurface(
        child: QuestraResponsiveListView(
          showScrollbar: true,
          padding: const EdgeInsets.all(20),
          children: [
            _GuildIntroCard(),
            const SizedBox(height: 16),
            if (!hasGuildContext) ...[
              ArcEmptyState(
                title: 'Guildで相談する準備をしましょう',
                message: 'QuestかTrailがひとつあるだけで、Guildへの相談はぐっと具体的になります。',
                actionLabel: 'Questを始める',
                icon: Icons.groups_outlined,
                onAction: () => context.go('${AppRoutes.quest}/create'),
              ),
              const SizedBox(height: 16),
            ],
            _GuildOverviewCard(
              activeQuestCount: activeQuests.length,
              openMissionCount: openMissions.length,
              trailCount: latestTrails.length,
              matchCount: guildMatches.length,
              review: postingReview,
            ),
            const SizedBox(height: 16),
            _GuildQuestionCard(question: question, review: postingReview),
            const SizedBox(height: 16),
            _GuildQuestMatchCard(matches: guildMatches),
            const SizedBox(height: 16),
            _GuildTrailReflectionCard(trails: latestTrails),
          ],
        ),
      ),
    );
  }

  String _buildGuildQuestion(
    List<Quest> activeQuests,
    List<Mission> openMissions,
  ) {
    if (openMissions.isNotEmpty) {
      final mission = openMissions.first;
      return '「${mission.questTitle}」で「${mission.title}」を進めたいです。小さく始めるなら、どこから手をつけるのがよいでしょうか？';
    }
    if (activeQuests.isNotEmpty) {
      final quest = activeQuests.first;
      return '「${quest.title}」を進めたいです。最初のMissionを小さくするなら、どんな一歩がよいでしょうか？';
    }
    return 'これから始めたいQuestがあります。まだ形が曖昧なので、最初の小さなMissionを一緒に考えてほしいです。';
  }
}

class _GuildOverviewCard extends StatelessWidget {
  const _GuildOverviewCard({
    required this.activeQuestCount,
    required this.openMissionCount,
    required this.trailCount,
    required this.matchCount,
    required this.review,
  });

  final int activeQuestCount;
  final int openMissionCount;
  final int trailCount;
  final int matchCount;
  final GuildPostingReview review;

  @override
  Widget build(BuildContext context) {
    final reviewLabel = switch (review.severity) {
      GuildPostingReviewSeverity.safe => '安全',
      GuildPostingReviewSeverity.caution => '確認',
      GuildPostingReviewSeverity.blocked => '修正',
    };

    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Guildの現在地', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('相談の材料、安全確認、近いQuestをまとめて見渡せます。競争ではなく、前へ進むために支え合う場所です。'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GuildStatusChip(
                icon: Icons.flag_outlined,
                label: 'Quest',
                value: '$activeQuestCount',
              ),
              _GuildStatusChip(
                icon: Icons.check_circle_outline,
                label: 'Mission',
                value: '$openMissionCount',
              ),
              _GuildStatusChip(
                icon: Icons.auto_stories_outlined,
                label: 'Trail',
                value: '$trailCount',
              ),
              _GuildStatusChip(
                icon: Icons.hub_outlined,
                label: '近いQuest',
                value: '$matchCount',
              ),
              _GuildStatusChip(
                icon: Icons.verified_user_outlined,
                label: 'Arc確認',
                value: reviewLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuildStatusChip extends StatelessWidget {
  const _GuildStatusChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$label $value',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuildQuestMatchCard extends StatelessWidget {
  const _GuildQuestMatchCard({required this.matches});

  final List<GuildQuestMatch> matches;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('近いQuest', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('近いQuestを持つ仲間を探すための候補です。private Questの詳細は表示しません。'),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            const Text('今は近い公開/Guild Questが見つかっていません。QuestやTrailが増えると精度が上がります。')
          else
            ...matches.map(
              (match) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GuildQuestMatchTile(match: match),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuildQuestMatchTile extends StatelessWidget {
  const _GuildQuestMatchTile({required this.match});

  final GuildQuestMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hub_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text('${match.category} / ${match.visibility.label}'),
                const SizedBox(height: 4),
                Text(match.reason),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${match.score}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _GuildIntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Guild', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            '同じQuestや価値観を持つ仲間に、Missionの相談やTrailの気づきを持ち寄る場所です。人気や順位ではなく、安心して前へ進むための航路です。',
          ),
        ],
      ),
    );
  }
}

class _GuildQuestionCard extends ConsumerWidget {
  const _GuildQuestionCard({required this.question, required this.review});

  final String question;
  final GuildPostingReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('相談ドラフト', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Guildへ持ち寄る前に、Arcが言葉の強さや個人情報の混入を軽く確認します。'),
          const SizedBox(height: 8),
          Text(question),
          const SizedBox(height: 12),
          _GuildPostingReviewPanel(review: review),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _copyQuestion(context, ref),
            icon: const Icon(Icons.copy),
            label: const Text('質問をコピー'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyQuestion(BuildContext context, WidgetRef ref) async {
    await Clipboard.setData(ClipboardData(text: question));
    await ref
        .read(analyticsServiceProvider)
        .guildDraftCreated(source: 'guild_question_card');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Guildへの質問をコピーしました。')));
    }
  }
}

class _GuildPostingReviewPanel extends StatelessWidget {
  const _GuildPostingReviewPanel({required this.review});

  final GuildPostingReview review;

  @override
  Widget build(BuildContext context) {
    final color = switch (review.severity) {
      GuildPostingReviewSeverity.safe => Colors.green,
      GuildPostingReviewSeverity.caution => Colors.orange,
      GuildPostingReviewSeverity.blocked => Colors.redAccent,
    };
    final title = switch (review.severity) {
      GuildPostingReviewSeverity.safe => 'Arcの確認: 安心して相談できそうです',
      GuildPostingReviewSeverity.caution => 'Arcの確認: 少しだけ見直しましょう',
      GuildPostingReviewSeverity.blocked => 'Arcの確認: 投稿前に修正しましょう',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (review.issues.isEmpty) ...[
            const SizedBox(height: 6),
            const Text('個人情報や強い表現は見つかっていません。'),
          ] else ...[
            const SizedBox(height: 8),
            ...review.issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('・${issue.label}: ${issue.message}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuildTrailReflectionCard extends StatelessWidget {
  const _GuildTrailReflectionCard({required this.trails});

  final List<Trail> trails;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('共有しやすいTrail', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (trails.isEmpty)
            const Text('Trailを残すと、Guildで相談しやすい気づきがここに並びます。')
          else
            ...trails.map(
              (trail) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trail.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(trail.summary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
