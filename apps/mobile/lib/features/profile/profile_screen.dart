import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/questra_primary_button.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
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
