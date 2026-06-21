import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/persistence/persistence_sync_state.dart';
import '../arc/arc_action_trigger_service.dart';
import '../arc/arc_bond_growth_service.dart';
import '../arc/arc_emotion_timeline_controller.dart';
import '../arc/arc_guidance_providers.dart';
import '../arc/stardust_service.dart';
import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_guide_model.dart';
import '../quest/quest_model.dart';
import '../tagging/tagging_providers.dart';
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

final missionSyncControllerProvider =
    NotifierProvider<PersistenceSyncController, PersistenceSyncState>(
      PersistenceSyncController.new,
    );

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
    _recordMissionEmotion(mission, trigger: ArcActionTrigger.missionCreated);
    unawaited(
      _persistMission(mission, sourceType: ArcMemorySourceType.missionCreated),
    );
    return mission;
  }

  Mission addMissionDraft({
    required Quest quest,
    required String title,
    required String description,
    required GuideType guideType,
    required MissionDifficulty difficulty,
  }) {
    final mission = Mission(
      questId: quest.id,
      questTitle: quest.title,
      title: title,
      description: description,
      guideType: guideType,
      difficulty: difficulty,
      status: MissionStatus.todo,
    );
    state = [mission, ...state];
    _recordMissionEmotion(mission, trigger: ArcActionTrigger.missionCreated);
    unawaited(
      _persistMission(mission, sourceType: ArcMemorySourceType.missionCreated),
    );
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
    _recordMissionEmotion(
      updatedMission,
      trigger: ArcActionTrigger.missionCompleted,
    );

    unawaited(
      _persistMission(
        updatedMission,
        sourceType: ArcMemorySourceType.missionCompleted,
      ),
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

    final sync = ref.read(missionSyncControllerProvider.notifier);
    sync.loading('Missionを読み込んでいます...');
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
      sync.saved('Missionを読み込みました。');
    } catch (error) {
      sync.failed('Mission load', error);
    }
  }

  void _loadForCurrentQuests() {
    final questIds = ref
        .read(questControllerProvider)
        .map((quest) => quest.id)
        .toList(growable: false);
    unawaited(loadForQuests(questIds));
  }

  Future<void> _persistMission(
    Mission mission, {
    required ArcMemorySourceType sourceType,
  }) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      ref
          .read(missionSyncControllerProvider.notifier)
          .failed('Mission save', 'ログインが必要です。');
      _recordMissionEmotion(
        mission,
        trigger: ArcActionTrigger.unauthenticated,
        surface: 'Mission保存',
      );
      return;
    }

    final sync = ref.read(missionSyncControllerProvider.notifier);
    sync.loading('Missionを保存しています...');
    try {
      final savedMission = await ref
          .read(missionRepositoryProvider)
          .save(mission);
      state = [
        for (final current in state)
          if (current.id == savedMission.id) savedMission else current,
      ];
      unawaited(_tagMission(userId, savedMission));
      _growBond(sourceType);
      await _rememberMission(savedMission, sourceType);
      sync.saved('Missionを保存しました。');
    } catch (error) {
      sync.failed('Mission save', error);
      _recordMissionEmotion(
        mission,
        trigger: ArcActionTrigger.saveFailure,
        surface: 'Mission保存',
      );
    }
  }

  void _recordMissionEmotion(
    Mission mission, {
    required ArcActionTrigger trigger,
    String? surface,
  }) {
    final decision = ref
        .read(arcActionTriggerServiceProvider)
        .resolve(
          trigger: trigger,
          missionTitle: mission.title,
          questTitle: mission.questTitle,
          surface: surface,
        );
    ref
        .read(arcEmotionTimelineControllerProvider.notifier)
        .record(
          emotion: decision.emotion,
          sourceType: decision.sourceType,
          reason: decision.message,
          sourceId: mission.id,
          questId: mission.questId,
          missionId: mission.id,
        );
  }

  void _growBond(ArcMemorySourceType sourceType) {
    final growth = ref
        .read(arcBondGrowthServiceProvider)
        .forMission(sourceType);
    final award = ref.read(stardustServiceProvider).forMission(sourceType);
    unawaited(
      ref
          .read(authControllerProvider.notifier)
          .addBondScore(delta: growth.delta, reason: growth.reason),
    );
    unawaited(
      ref
          .read(authControllerProvider.notifier)
          .addStardust(amount: award.amount, reason: award.reason),
    );
  }

  Future<void> _tagMission(String userId, Mission mission) async {
    try {
      await ref
          .read(taggingServiceProvider)
          .tagMission(ownerId: userId, mission: mission);
    } catch (_) {
      // Tagging should not block Mission save or completion.
    }
  }

  Future<void> _saveTrailEvent(TrailEvent event) async {
    try {
      await ref.read(trailEventRepositoryProvider).save(event);
    } catch (error) {
      ref
          .read(missionSyncControllerProvider.notifier)
          .failed('Trail event save', error);
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
