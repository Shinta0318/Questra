import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/questra_card.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_model.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_model.dart';

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
    final openMissions =
        missions
            .where((mission) => mission.status == MissionStatus.todo)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latestTrails = [...trails]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final question = _buildGuildQuestion(activeQuests, openMissions);

    return Scaffold(
      appBar: AppBar(title: const Text('Guild')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _GuildIntroCard(),
            const SizedBox(height: 16),
            _GuildQuestionCard(question: question),
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
            ...trails
                .take(3)
                .map(
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
