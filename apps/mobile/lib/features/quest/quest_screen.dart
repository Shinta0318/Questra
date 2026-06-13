import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/questra_card.dart';
import '../arc/arc_emotion.dart';
import '../arc/arc_widget.dart';
import 'quest_controller.dart';
import 'quest_model.dart';

class QuestScreen extends ConsumerWidget {
  const QuestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(questControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        actions: [
          IconButton(
            tooltip: 'Create quest',
            onPressed: () => context.go('${AppRoutes.quest}/create'),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: quests.length + 1,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const QuestraCard(
                child: ArcWidget(
                  emotion: ArcEmotion.serious,
                  message: 'Choose the quest that deserves your next move.',
                ),
              );
            }

            final quest = quests[index - 1];
            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => context.go('${AppRoutes.quest}/${quest.id}'),
              child: QuestraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(quest.description),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(quest.difficulty.label)),
                        Chip(label: Text(quest.status.label)),
                        Chip(label: Text(quest.visibility.label)),
                        if (quest.targetDate != null)
                          Chip(
                            label: Text(
                              DateFormat.MMMd().format(quest.targetDate!),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
