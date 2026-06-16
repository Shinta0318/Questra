import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import '../quest/quest_controller.dart';
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
  List<Mission> build() {
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        _loadForCurrentQuests();
      }
    });

    ref.listen(questControllerProvider, (previous, next) {
      final userId = ref.read(authControllerProvider).profile?.id;
      if (userId != null) {
        loadForQuests(next.map((quest) => quest.id).toList(growable: false));
      }
    });

    if (ref.read(authControllerProvider).profile?.id != null) {
      unawaited(Future<void>.microtask(_loadForCurrentQuests));
    }

    return const [];
  }

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
    unawaited(_persistMission(mission));
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

    unawaited(_persistMission(updatedMission));
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
      _saveTrailEvent(
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

  Future<void> loadForQuests(List<String> questIds) async {
    if (questIds.isEmpty) {
      state = const [];
      return;
    }

    try {
      final loaded = await ref
          .read(missionRepositoryProvider)
          .findManyByQuestIds(questIds);
      final loadedIds = loaded.map((mission) => mission.id).toSet();
      final questIdSet = questIds.toSet();
      final localOnly = state.where(
        (mission) =>
            questIdSet.contains(mission.questId) &&
            !loadedIds.contains(mission.id),
      );
      state = [...loaded, ...localOnly];
    } catch (_) {
      // Mission sync state is introduced later; keep local state for now.
    }
  }

  void _loadForCurrentQuests() {
    final questIds = ref
        .read(questControllerProvider)
        .map((quest) => quest.id)
        .toList(growable: false);
    unawaited(loadForQuests(questIds));
  }

  Future<void> _persistMission(Mission mission) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      return;
    }

    try {
      await ref.read(missionRepositoryProvider).save(mission);
    } catch (_) {
      // Mission sync state is introduced later; keep optimistic local state now.
    }
  }

  Future<void> _saveTrailEvent(TrailEvent event) async {
    try {
      await ref.read(trailEventRepositoryProvider).save(event);
    } catch (_) {
      // Trail event sync state is introduced later; keep the completed Mission.
    }
  }

  Future<void> _rememberMission(
    Mission mission,
    ArcMemorySourceType sourceType,
  ) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      return;
    }

    try {
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
    } catch (_) {
      // Arc Memory sync state is introduced later; keep the Mission action.
    }
  }
}
