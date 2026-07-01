import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/questra_colors.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/questra_primary_button.dart';
import '../arc/arc_bond_service.dart';
import '../arc/navigator_rank_service.dart';
import '../arc/stardust_service.dart';
import '../auth/auth_controller.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_model.dart';
import '../trail/trail_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile;
    final quests = ref.watch(questControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    final trails = ref.watch(trailControllerProvider);
    final activeQuestCount = quests
        .where((quest) => quest.status == QuestStatus.active)
        .length;
    final openMissionCount = missions
        .where((mission) => mission.status == MissionStatus.todo)
        .length;
    final bond = ref
        .watch(arcBondServiceProvider)
        .resolve(profile?.bondScore ?? 0);
    final stardust = ref
        .watch(stardustServiceProvider)
        .resolve(profile?.stardustBalance ?? 0);
    final navigatorRank = ref
        .watch(navigatorRankServiceProvider)
        .resolve(
          quests: quests,
          missions: missions,
          trails: trails,
          bondScore: profile?.bondScore ?? 0,
          stardustBalance: profile?.stardustBalance ?? 0,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: QuestraResponsiveListView(
          maxContentWidth: 720,
          padding: const EdgeInsets.all(20),
          children: [
            QuestraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.nickname ?? 'Guest',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(profile?.email ?? 'Not logged in'),
                  const SizedBox(height: 8),
                  Text(
                    profile == null
                        ? 'Journey owner: Guest session'
                        : 'Journey owner: ${profile.id}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Chip(
                    label: Text(
                      profile?.onboardingCompleted == true
                          ? 'Onboarding complete'
                          : 'Onboarding needed',
                    ),
                  ),
                  const SizedBox(height: 20),
                  QuestraPrimaryButton(
                    label: profile == null ? 'Login' : 'Logout',
                    onPressed: () async {
                      if (profile == null) {
                        context.go(AppRoutes.login);
                        return;
                      }
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) {
                        context.go(AppRoutes.login);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ArcBondCard(bond: bond, profileAvailable: profile != null),
            const SizedBox(height: 16),
            _StardustCard(
              stardust: stardust,
              profileAvailable: profile != null,
            ),
            const SizedBox(height: 16),
            _NavigatorRankCard(
              rank: navigatorRank,
              storedRank: profile?.navigatorRank,
            ),
            const SizedBox(height: 16),
            QuestraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Journey State',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ProfileMetric(
                        label: 'Active Quests',
                        value: activeQuestCount.toString(),
                      ),
                      _ProfileMetric(
                        label: 'Open Missions',
                        value: openMissionCount.toString(),
                      ),
                      _ProfileMetric(
                        label: 'Trails',
                        value: trails.length.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile == null
                        ? 'Log in to keep this journey connected across devices.'
                        : 'Quest, Mission, Trail, and Arc Memory data use this profile as the owner boundary.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StardustCard extends StatelessWidget {
  const _StardustCard({required this.stardust, required this.profileAvailable});

  final StardustState stardust;
  final bool profileAvailable;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: QuestraColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.auto_awesome, color: QuestraColors.gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stardust', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  profileAvailable
                      ? stardust.description
                      : 'ログインすると活動のしるしをプロフィールに保存できます。',
                ),
                const SizedBox(height: 10),
                Text(
                  '${stardust.balance}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: QuestraColors.deepNavy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(stardust.label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigatorRankCard extends StatelessWidget {
  const _NavigatorRankCard({required this.rank, required this.storedRank});

  final NavigatorRankState rank;
  final String? storedRank;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: QuestraColors.cosmicBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.explore_outlined,
                  color: QuestraColors.cosmicBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Navigator Rank',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(rank.description),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            rank.label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: QuestraColors.deepNavy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rank.progressToNext,
              minHeight: 10,
              backgroundColor: QuestraColors.cloud,
              valueColor: const AlwaysStoppedAnimation<Color>(
                QuestraColors.cosmicBlue,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Rank score ${rank.score}')),
              if (storedRank != null) Chip(label: Text('Saved $storedRank')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcBondCard extends StatelessWidget {
  const _ArcBondCard({required this.bond, required this.profileAvailable});

  final ArcBondState bond;
  final bool profileAvailable;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ArcWidget(
                emotion: ArcEmotion.support,
                size: 72,
                showSpeechBubble: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arc Bond',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profileAvailable
                          ? bond.description
                          : 'ログインするとArcとの航路をこのプロフィールに保存できます。',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: bond.progress,
                    minHeight: 10,
                    backgroundColor: QuestraColors.cloud,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      QuestraColors.gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${bond.score}',
                style: const TextStyle(
                  color: QuestraColors.deepNavy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Chip(label: Text(bond.label)),
        ],
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
