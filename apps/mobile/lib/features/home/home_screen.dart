import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/questra_primary_button.dart';
import '../arc/arc_emotion.dart';
import '../arc/arc_widget.dart';
import '../auth/auth_controller.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_guide_model.dart';
import '../quest/quest_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final quests = ref.watch(questControllerProvider);
    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .toList();
    final missions = ref.watch(missionControllerProvider);
    final openMissions =
        missions
            .where((mission) => mission.status == MissionStatus.todo)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final todaysMission = openMissions.isEmpty ? null : openMissions.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            QuestraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ArcWidget(
                    emotion: ArcEmotion.support,
                    message:
                        '${profile?.nickname ?? '旅人'}、君の航路を覚えているよ。このQuestは大切な星になりそうだね。',
                  ),
                  const SizedBox(height: 20),
                  QuestraPrimaryButton(
                    label: 'Questへ進む',
                    onPressed: () => context.go(AppRoutes.quest),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (todaysMission == null)
              _HomeSection(
                title: '今日のMission',
                body: activeQuests.isEmpty
                    ? 'まずはQuestをひとつ灯そう。小さなMissionはそこから見えてくるよ。'
                    : 'Quest詳細から、今日進めるMissionを選ぼう。',
              )
            else
              QuestraCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日のMission',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(todaysMission.title),
                    const SizedBox(height: 6),
                    Text('Quest: ${todaysMission.questTitle}'),
                    Text('Guide: ${todaysMission.guideType.label}'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _completeMission(context, ref, todaysMission),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Missionを完了'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _HomeSection(
              title: 'Questの航路',
              body:
                  '進行中 ${activeQuests.length} / 全 ${quests.length} Quest。焦らず、星をひとつずつ。',
            ),
            const SizedBox(height: 12),
            const _HomeSection(
              title: '最近のTrail',
              body: 'このTrailは君の旅の証だね。小さな前進も、ちゃんと残っているよ。',
            ),
            const SizedBox(height: 12),
            _HomeActions(
              onOpenGuild: () => context.go(AppRoutes.guild),
              onOpenArc: () => context.go(AppRoutes.arc),
              onOpenProfile: () => context.go(AppRoutes.profile),
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
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Mission完了。Trailに今日の一歩を残しました。')));
}

class _HomeActions extends StatelessWidget {
  const _HomeActions({
    required this.onOpenGuild,
    required this.onOpenArc,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenGuild;
  final VoidCallback onOpenArc;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('次の寄港地', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenArc,
                icon: const Icon(Icons.travel_explore_outlined),
                label: const Text('Arc Chat'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenGuild,
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Guild'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenProfile,
                icon: const Icon(Icons.person_outline),
                label: const Text('Profile'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body),
        ],
      ),
    );
  }
}
