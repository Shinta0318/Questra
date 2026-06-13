import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/questra_primary_button.dart';
import '../arc/arc_emotion.dart';
import '../arc/arc_widget.dart';
import '../auth/auth_controller.dart';
import '../quest/quest_controller.dart';
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
                        'Welcome ${profile?.nickname ?? 'Adventurer'}. Your arc is moving.',
                  ),
                  const SizedBox(height: 20),
                  QuestraPrimaryButton(
                    label: 'Open Quests',
                    onPressed: () => context.go(AppRoutes.quest),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _HomeSection(
              title: "Today's Mission",
              body: activeQuests.isEmpty
                  ? 'Create a quest and choose one next action.'
                  : 'Advance "${activeQuests.first.title}".',
            ),
            const SizedBox(height: 12),
            _HomeSection(
              title: 'Quest Progress',
              body:
                  '${activeQuests.length} active / ${quests.length} total quests',
            ),
            const SizedBox(height: 12),
            const _HomeSection(
              title: 'Recent Story',
              body: 'Arc noticed your first pattern: small steps become lore.',
            ),
            const SizedBox(height: 12),
            const _HomeSection(
              title: 'Guild Preview',
              body:
                  'No guild yet. A future party can join your adventure here.',
            ),
          ],
        ),
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
