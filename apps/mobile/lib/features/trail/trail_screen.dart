import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/questra_colors.dart';
import '../../widgets/questra_card.dart';
import 'trail_controller.dart';
import 'trail_model.dart';

class TrailScreen extends ConsumerWidget {
  const TrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trails = ref.watch(trailControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trail')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            QuestraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trail',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Trailは、QuestやMissionを通じて残す挑戦記録・達成記録・体験の軌跡です。'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...trails.map(
              (trail) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: QuestraCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: QuestraColors.gold.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              trail.trailType.label,
                              style: const TextStyle(
                                color: QuestraColors.deepNavy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(DateFormat.MMMd('ja').format(trail.createdAt)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        trail.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(trail.summary),
                      const SizedBox(height: 8),
                      Text(
                        trail.questId == null
                            ? 'Quest: 未紐づけ'
                            : 'Quest: ${trail.questId}',
                        style: const TextStyle(color: QuestraColors.slate),
                      ),
                      if (trail.missionId != null)
                        Text(
                          'Mission: ${trail.missionId}',
                          style: const TextStyle(color: QuestraColors.slate),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
