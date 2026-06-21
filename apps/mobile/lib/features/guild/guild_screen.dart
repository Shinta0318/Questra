import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/performance/performance_limits.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/questra_card.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_model.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_model.dart';
import 'guild_quest_matching_service.dart';

final guildQuestMatchingServiceProvider = Provider<GuildQuestMatchingService>((
  ref,
) {
  return const GuildQuestMatchingService();
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _GuildIntroCard(),
            const SizedBox(height: 16),
            if (!hasGuildContext) ...[
              ArcEmptyState(
                title: 'Guildに持ち寄る航路を準備しましょう',
                message: 'QuestかTrailがひとつあるだけで、Guildへの相談はぐっと具体的になります。',
                actionLabel: 'Questを始める',
                icon: Icons.groups_outlined,
                onAction: () => context.go('${AppRoutes.quest}/create'),
              ),
              const SizedBox(height: 16),
            ],
            _GuildQuestionCard(question: question),
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
      return '「${mission.questTitle}」で「${mission.title}」を進めたいです。小さく始めるために、どこから手をつけるとよさそうですか？';
    }
    if (activeQuests.isNotEmpty) {
      final quest = activeQuests.first;
      return '「${quest.title}」を進めたいです。最初のMissionを小さくするなら、どんな一歩がよさそうですか？';
    }
    return 'これから始めたいQuestがあります。まだ形が曖昧なので、最初の小さなMissionを一緒に考えてほしいです。';
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
          Text('Quest Matching', style: Theme.of(context).textTheme.titleLarge),
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
          const Text('同じQuestや価値観を持つ仲間に、Missionの相談やTrailの気づきを持ち寄る場所です。'),
        ],
      ),
    );
  }
}

class _GuildQuestionCard extends StatelessWidget {
  const _GuildQuestionCard({required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question Draft', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(question),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _copyQuestion(context),
            icon: const Icon(Icons.copy),
            label: const Text('Copy question'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyQuestion(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: question));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Guildへの質問をコピーしました。')));
    }
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
          Text(
            'Safe Trail Reflections',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
