import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/questra_colors.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/questra_card.dart';
import '../quest/quest_guide_model.dart';
import 'mission_controller.dart';
import 'mission_model.dart';

class MissionScreen extends ConsumerWidget {
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(missionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const QuestraCard(
              child: ArcWidget(
                emotion: ArcEmotion.support,
                message: '小さなMissionも、ちゃんと前進だよ。今日の星をひとつ選ぼう。',
              ),
            ),
            const SizedBox(height: 16),
            if (missions.isEmpty)
              const QuestraCard(
                child: Text('Quest詳細からMissionを生成すると、ここに今日の一歩が並びます。'),
              )
            else
              ...missions.map(
                (mission) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: QuestraCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mission.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(mission.description),
                        const SizedBox(height: 10),
                        Text('Quest: ${mission.questTitle}'),
                        Text('Guide: ${mission.guideType.label}'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: mission.status == MissionStatus.completed
                              ? null
                              : () => ref
                                    .read(missionControllerProvider.notifier)
                                    .completeMission(mission.id),
                          icon: Icon(
                            mission.status == MissionStatus.completed
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            color: QuestraColors.gold,
                          ),
                          label: Text(
                            mission.status == MissionStatus.completed
                                ? '完了済み'
                                : 'Missionを完了',
                          ),
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
