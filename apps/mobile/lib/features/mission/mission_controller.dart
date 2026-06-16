import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import '../quest/quest_guide_model.dart';
import '../quest/quest_model.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_event_model.dart';
import '../trail/trail_providers.dart';
import 'mission_generation_service.dart';
import 'mission_model.dart';
import 'mission_providers.dart';

final missionGenerationServiceProvider = Provider<MissionGenerationService>(
  (ref) => const MissionGenerationService(),
);

final missionControllerProvider =
    NotifierProvider<MissionController, List<Mission>>(MissionController.new);

class MissionController extends Notifier<List<Mission>> {
  @override
  List<Mission> build() => const [];

  Mission? get todaysMission {
    final openMissions = state
        .where((mission) => mission.status == MissionStatus.todo)
        .toList();
    if (openMissions.isEmpty) {
      return null;
    }
    openMissions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return openMissions.first;
  }

  Mission generateMission({
    required Quest quest,
    required QuestGuide guide,
    ArcAdvice? advice,
  }) {
    final mission = ref
        .read(missionGenerationServiceProvider)
        .generate(quest: quest, guide: guide, advice: advice);
    state = [mission, ...state];
    unawaited(_rememberMission(mission, ArcMemorySourceType.missionCreated));
    return mission;
  }

  Mission? completeMission(String missionId) {
    final completedMission = state
        .where((mission) => mission.id == missionId)
        .firstOrNull;
    if (completedMission == null ||
        completedMission.status == MissionStatus.completed) {
      return null;
    }
    final updatedMission = completedMission.copyWith(
      status: MissionStatus.completed,
    );
    state = [
      for (final mission in state)
        if (mission.id == missionId) updatedMission else mission,
    ];

    unawaited(ref.read(missionRepositoryProvider).save(updatedMission));
    unawaited(
      _rememberMission(updatedMission, ArcMemorySourceType.missionCompleted),
    );
    final trail = ref
        .read(trailControllerProvider.notifier)
        .addQuestTrail(
          questId: completedMission.questId,
          missionId: completedMission.id,
          questTitle: completedMission.questTitle,
        );
    unawaited(
      ref
          .read(trailEventRepositoryProvider)
          .save(
            TrailEvent(
              trailId: trail.id,
              questId: completedMission.questId,
              missionId: completedMission.id,
              eventType: TrailEventType.missionCompleted,
              content: 'Mission completed: ${completedMission.title}',
            ),
          ),
    );
    return updatedMission;
  }

  Future<void> _rememberMission(
    Mission mission,
    ArcMemorySourceType sourceType,
  ) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      return;
    }

    await ref
        .read(memoryExtractionServiceProvider)
        .extractAndSave(
          MemoryExtractionEvent(
            userId: userId,
            questId: mission.questId,
            missionId: mission.id,
            sourceId: mission.id,
            sourceType: sourceType,
            title: 'Mission memory',
            text: '${mission.title}: ${mission.description}',
            metadata: {'status': mission.status.storageKey},
          ),
        );
    ref.invalidate(visibleArcMemoriesProvider);
  }
}
