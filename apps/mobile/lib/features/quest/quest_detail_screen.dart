import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/questra_primary_button.dart';
import '../arc/arc_widget.dart';
import '../mission/mission_controller.dart';
import 'quest_controller.dart';
import 'quest_guide_controller.dart';
import 'quest_guide_model.dart';
import 'quest_model.dart';

class QuestDetailScreen extends ConsumerWidget {
  const QuestDetailScreen({required this.questId, super.key});

  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref
        .watch(questControllerProvider)
        .where((quest) => quest.id == questId);
    final current = quest.isEmpty ? null : quest.first;
    final guideController = ref.read(questGuideControllerProvider.notifier);
    final guides =
        ref.watch(questGuideControllerProvider).guidesByQuest[questId] ??
        const [];
    final advice =
        ref.watch(questGuideControllerProvider).adviceByQuest[questId] ??
        const [];
    final starMap =
        ref.watch(questGuideControllerProvider).starMapByQuest[questId] ??
        const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Quest Detail')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: current == null
              ? const Center(child: Text('Quest not found.'))
              : ListView(
                  children: [
                    QuestraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            current.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(current.description),
                          const SizedBox(height: 16),
                          Text('Difficulty: ${current.difficulty.label}'),
                          Text('Status: ${current.status.label}'),
                          Text('Visibility: ${current.visibility.label}'),
                          Text(
                            'Target: ${current.targetDate == null ? 'None' : DateFormat.yMMMd().format(current.targetDate!)}',
                          ),
                          const SizedBox(height: 20),
                          QuestraPrimaryButton(
                            label: 'Edit',
                            onPressed: () => context.go(
                              '${AppRoutes.quest}/${current.id}/edit',
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(questControllerProvider.notifier)
                                  .remove(current.id);
                              context.go(AppRoutes.quest);
                            },
                            child: const Text('Delete Quest'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (guides.isEmpty)
                      QuestraCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quest Decomposition System',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text('Generate Guides for this Quest.'),
                            const SizedBox(height: 12),
                            QuestraPrimaryButton(
                              label: 'Generate Guides',
                              onPressed: () =>
                                  guideController.generateForQuest(current),
                            ),
                          ],
                        ),
                      )
                    else
                      ...guides.map(
                        (guide) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _GuideCard(
                            quest: current,
                            guide: guide,
                            advice: _firstAdvice(advice, guide.guideType),
                            starMap: starMap
                                .where(
                                  (item) => item.guideType == guide.guideType,
                                )
                                .toList(),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  ArcAdvice? _firstAdvice(List<ArcAdvice> advice, GuideType guideType) {
    for (final item in advice) {
      if (item.guideType == guideType) {
        return item;
      }
    }
    return null;
  }
}

class _GuideCard extends ConsumerWidget {
  const _GuideCard({
    required this.quest,
    required this.guide,
    required this.advice,
    required this.starMap,
  });

  final Quest quest;
  final QuestGuide guide;
  final ArcAdvice? advice;
  final List<StarMapItem> starMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(guide.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(guide.description),
          const SizedBox(height: 12),
          Text(
            'Suggested actions',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          ...guide.suggestedActions.map((action) => Text('• $action')),
          if (advice != null) ...[
            const SizedBox(height: 16),
            ArcWidget(
              emotion: advice!.emotion,
              size: 72,
              message: advice!.adviceText,
            ),
            const SizedBox(height: 4),
            Text('source_type: ${advice!.sourceType}'),
          ],
          if (starMap.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Star Map', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            ...starMap.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.title),
                subtitle: Text(
                  '${item.contentType} • ${item.sourceType}\n${item.description}\n${item.url}',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ref
                  .read(missionControllerProvider.notifier)
                  .generateMission(quest: quest, guide: guide, advice: advice);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mission generated for today.')),
              );
            },
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Generate Mission'),
          ),
        ],
      ),
    );
  }
}
