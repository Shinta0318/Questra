import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/questra_primary_button.dart';
import 'quest_controller.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Quest Detail')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: current == null
              ? const Center(child: Text('Quest not found.'))
              : QuestraCard(
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
                        onPressed: () =>
                            context.go('${AppRoutes.quest}/${current.id}/edit'),
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
        ),
      ),
    );
  }
}
