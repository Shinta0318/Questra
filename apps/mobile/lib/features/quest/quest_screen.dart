import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/questra_colors.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';
import 'quest_controller.dart';
import 'quest_model.dart';

class QuestScreen extends ConsumerWidget {
  const QuestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(questControllerProvider);
    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .toList();

    return Scaffold(
      backgroundColor: QuestraColors.deepNavy,
      appBar: AppBar(
        title: const Text('Quest一覧'),
        actions: [
          IconButton(
            tooltip: '新しいQuestを始める',
            onPressed: () => context.go('${AppRoutes.quest}/create'),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            _QuestHero(
              activeCount: activeQuests.length,
              onCreateQuest: () => context.go('${AppRoutes.quest}/create'),
            ),
            const SizedBox(height: 22),
            Text(
              '進行中のQuest',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: QuestraColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...quests.map(
              (quest) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _QuestCard(
                  quest: quest,
                  onTap: () => context.go('${AppRoutes.quest}/${quest.id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestHero extends StatelessWidget {
  const _QuestHero({required this.activeCount, required this.onCreateQuest});

  final int activeCount;
  final VoidCallback onCreateQuest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [QuestraColors.midnightNavy, QuestraColors.cosmicBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: QuestraColors.gold.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: QuestraColors.cosmicBlue.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          const ArcWidget(
            emotion: ArcEmotion.serious,
            size: 86,
            showSpeechBubble: false,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quest一覧',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: QuestraColors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '進行中のQuest $activeCount 件',
                  style: const TextStyle(
                    color: QuestraColors.parchment,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onCreateQuest,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('新しいQuestを始める'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest, required this.onTap});

  final Quest quest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (quest.progress.clamp(0, 1) * 100).round();

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: QuestraColors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: QuestraColors.cosmicBlue.withValues(alpha: 0.20),
          ),
          boxShadow: [
            BoxShadow(
              color: QuestraColors.skyBlue.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: QuestraColors.deepNavy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.travel_explore,
                    color: QuestraColors.gold,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        quest.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: quest.progress.clamp(0, 1),
                      minHeight: 9,
                      backgroundColor: QuestraColors.cloud,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        QuestraColors.gold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    color: QuestraColors.deepNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuestPill(
                  icon: Icons.flag_outlined,
                  label: quest.status.label,
                  emphasized: quest.status == QuestStatus.active,
                ),
                _QuestPill(
                  icon: Icons.fitness_center_outlined,
                  label: quest.difficulty.label,
                ),
                _QuestPill(
                  icon: Icons.category_outlined,
                  label: quest.category,
                ),
                if (quest.targetDate != null)
                  _QuestPill(
                    icon: Icons.event_outlined,
                    label: DateFormat.MMMd('ja').format(quest.targetDate!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestPill extends StatelessWidget {
  const _QuestPill({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: emphasized
            ? QuestraColors.gold.withValues(alpha: 0.22)
            : QuestraColors.cosmicBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? QuestraColors.gold.withValues(alpha: 0.58)
              : QuestraColors.cosmicBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: emphasized
                ? QuestraColors.deepNavy
                : QuestraColors.cosmicBlue,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: emphasized
                  ? QuestraColors.deepNavy
                  : QuestraColors.midnightNavy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
