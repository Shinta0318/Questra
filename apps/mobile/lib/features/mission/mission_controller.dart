import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/estimation/effort_estimate.dart';
import '../../core/persistence/persistence_sync_state.dart';
import '../arc/arc_action_trigger_service.dart';
import '../arc/arc_bond_growth_service.dart';
import '../arc/arc_emotion_timeline_controller.dart';
import '../arc/arc_guidance_providers.dart';
import '../arc/stardust_service.dart';
import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import '../business_foundation/mission_support_profile.dart';
import '../business_foundation/mission_support_profile_repository.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_guide_model.dart';
import '../quest/quest_model.dart';
import '../quest/planning_preferences_controller.dart';
import '../quest/quest_progress_service.dart';
import '../quest/route_replanning_repository.dart';
import '../tagging/tagging_providers.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_event_model.dart';
import '../trail/trail_providers.dart';
import 'mission_generation_service.dart';
import 'mission_contract_service.dart';
import 'mission_model.dart';
import 'mission_availability_recalculation_service.dart';
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
    ref.listen(planningPreferencesControllerProvider, (previous, next) {
      if (previous == null ||
          previous.availability.totalMinutes ==
              next.availability.totalMinutes) {
        return;
      }
      _recalculateForAvailability(
        previous.availability.totalMinutes,
        next.availability.totalMinutes,
      );
    });
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (next == previous) return;
      state = const [];
      if (next != null) _loadForCurrentQuests();
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
    openMissions.sort((a, b) {
      if (a.isToday != b.isToday) return a.isToday ? -1 : 1;
      return a.sortOrder.compareTo(b.sortOrder);
    });
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
    _syncQuestProgress(quest.id);
    _recordMissionEmotion(mission, trigger: ArcActionTrigger.missionCreated);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .progress(
            name: AnalyticsEventName.missionCreated,
            userId: ref.read(authControllerProvider).profile?.id,
            questId: quest.id,
            missionId: mission.id,
            properties: {
              'difficulty_band': mission.difficulty.name,
              'status': mission.status.name,
            },
          ),
    );
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
    int? sortOrder,
    bool isToday = false,
    EffortEstimate? effortEstimate,
    String? id,
    String? parentMissionId,
    List<String> dependencyIds = const [],
    MissionPriority priority = MissionPriority.normal,
    String category = '実行',
    String? estimatedCostLabel,
    List<String> referenceHints = const [],
    List<String> enterpriseSupportHints = const [],
    int? difficultyScore,
    int? estimatedDurationDays,
    String doneCondition = '',
    String expectedOutput = '',
    String verificationType = 'self_check',
    String action = '',
    bool isOptional = false,
    String sourceRequirement = 'none',
    double confidence = 0.5,
  }) {
    final titleError = const MissionContractService().validateTitle(
      questTitle: quest.title,
      missionTitle: title,
      existingTitles: state
          .where((mission) => mission.questId == quest.id)
          .map((mission) => mission.title),
    );
    if (titleError != null) {
      throw ArgumentError.value(title, 'title', titleError);
    }
    final nextSortOrder =
        sortOrder ??
        state.where((mission) => mission.questId == quest.id).length;
    final clearedToday = isToday
        ? state
              .where(
                (mission) => mission.questId == quest.id && mission.isToday,
              )
              .map((mission) => mission.copyWith(isToday: false))
              .toList(growable: false)
        : const <Mission>[];
    final clearedById = {
      for (final mission in clearedToday) mission.id: mission,
    };
    final mission = Mission(
      id: id,
      questId: quest.id,
      questTitle: quest.title,
      title: title,
      description: description,
      guideType: guideType,
      difficulty: difficulty,
      status: MissionStatus.todo,
      sortOrder: nextSortOrder,
      isToday: isToday,
      effortEstimate: effortEstimate,
      parentMissionId: parentMissionId,
      dependencyIds: dependencyIds,
      priority: priority,
      category: category,
      estimatedCostLabel: estimatedCostLabel,
      referenceHints: referenceHints,
      enterpriseSupportHints: enterpriseSupportHints,
      difficultyScore: difficultyScore,
      estimatedDurationDays: estimatedDurationDays,
      doneCondition: doneCondition,
      expectedOutput: expectedOutput,
      verificationType: verificationType,
      action: action,
      isOptional: isOptional,
      sourceRequirement: sourceRequirement,
      confidence: confidence,
    );
    state = [
      mission,
      for (final current in state) clearedById[current.id] ?? current,
    ];
    for (final cleared in clearedToday) {
      unawaited(
        _persistMission(
          cleared,
          sourceType: ArcMemorySourceType.missionCreated,
          recordJourney: false,
        ),
      );
    }
    _syncQuestProgress(quest.id);
    _recordMissionEmotion(mission, trigger: ArcActionTrigger.missionCreated);
    unawaited(
      _persistMission(mission, sourceType: ArcMemorySourceType.missionCreated),
    );
    return mission;
  }

  void updateMission(Mission updatedMission) {
    final titleError = const MissionContractService().validateTitle(
      questTitle: updatedMission.questTitle,
      missionTitle: updatedMission.title,
      existingTitles: state
          .where(
            (mission) =>
                mission.questId == updatedMission.questId &&
                mission.id != updatedMission.id,
          )
          .map((mission) => mission.title),
    );
    if (titleError != null) {
      throw ArgumentError.value(updatedMission.title, 'title', titleError);
    }
    state = [
      for (final mission in state)
        if (mission.id == updatedMission.id) updatedMission else mission,
    ];
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .progress(
            name: AnalyticsEventName.missionUpdated,
            userId: ref.read(authControllerProvider).profile?.id,
            questId: updatedMission.questId,
            missionId: updatedMission.id,
            properties: {'status': updatedMission.status.name},
          ),
    );
    unawaited(
      _persistMission(
        updatedMission,
        sourceType: ArcMemorySourceType.missionCreated,
        recordJourney: false,
      ),
    );
  }

  void _recalculateForAvailability(
    int previousWeeklyMinutes,
    int nextWeeklyMinutes,
  ) {
    const service = MissionAvailabilityRecalculationService();
    final updates = <Mission>[];
    for (final mission in state) {
      final updated = service.recalculate(
        mission,
        previousWeeklyMinutes: previousWeeklyMinutes,
        nextWeeklyMinutes: nextWeeklyMinutes,
      );
      if (updated.estimatedDurationDays != mission.estimatedDurationDays) {
        updates.add(updated);
      }
    }
    if (updates.isEmpty) return;
    final byId = {for (final mission in updates) mission.id: mission};
    state = [for (final mission in state) byId[mission.id] ?? mission];
    for (final mission in updates) {
      unawaited(
        _persistMission(
          mission,
          sourceType: ArcMemorySourceType.missionCreated,
          recordJourney: false,
        ),
      );
    }
  }

  void updateProgress(String missionId, int progressPercent) {
    final mission = state.where((item) => item.id == missionId).firstOrNull;
    if (mission == null) return;
    final normalized = progressPercent.clamp(0, 100);
    final updated = mission.copyWith(
      progressPercent: normalized,
      status: normalized == 100 ? MissionStatus.completed : MissionStatus.todo,
    );
    state = [
      for (final item in state)
        if (item.id == missionId) updated else item,
    ];
    _syncQuestProgress(updated.questId);
    unawaited(
      _persistMission(
        updated,
        sourceType: normalized == 100
            ? ArcMemorySourceType.missionCompleted
            : ArcMemorySourceType.missionCreated,
        recordJourney: normalized == 100,
      ),
    );
    if (normalized == 100) {
      unawaited(_recordRouteProgressEvent(updated, 'completed'));
    }
  }

  void removeMission(String missionId) {
    final mission = state.where((item) => item.id == missionId).firstOrNull;
    final questId = mission?.questId;
    state = state.where((mission) => mission.id != missionId).toList();
    if (mission != null) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .progress(
              name: AnalyticsEventName.missionDeleted,
              userId: ref.read(authControllerProvider).profile?.id,
              questId: mission.questId,
              missionId: mission.id,
            ),
      );
    }
    if (questId != null) _syncQuestProgress(questId);
    unawaited(_deleteMission(missionId));
  }

  void archiveForRoute(String missionId) {
    final mission = state.where((item) => item.id == missionId).firstOrNull;
    if (mission == null || mission.status == MissionStatus.completed) return;
    final archived = mission.copyWith(routeState: MissionRouteState.removed);
    state = state.where((item) => item.id != missionId).toList();
    _syncQuestProgress(mission.questId);
    unawaited(
      _persistMission(
        archived,
        sourceType: ArcMemorySourceType.missionCreated,
        recordJourney: false,
      ),
    );
  }

  void restoreForRoute(Mission mission) {
    final restored = mission.copyWith(routeState: MissionRouteState.active);
    state = [restored, ...state.where((item) => item.id != restored.id)];
    _syncQuestProgress(restored.questId);
    unawaited(
      _persistMission(
        restored,
        sourceType: ArcMemorySourceType.missionCreated,
        recordJourney: false,
      ),
    );
  }

  void reorderForQuest(String questId, int oldIndex, int newIndex) {
    final ordered =
        state.where((mission) => mission.questId == questId).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    if (newIndex < 0 || newIndex >= ordered.length) return;
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    final updated = [
      for (var index = 0; index < ordered.length; index++)
        ordered[index].copyWith(sortOrder: index),
    ];
    final byId = {for (final mission in updated) mission.id: mission};
    state = [for (final mission in state) byId[mission.id] ?? mission];
    for (final mission in updated) {
      unawaited(
        _persistMission(
          mission,
          sourceType: ArcMemorySourceType.missionCreated,
          recordJourney: false,
        ),
      );
    }
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .progress(
            name: AnalyticsEventName.missionReordered,
            userId: ref.read(authControllerProvider).profile?.id,
            questId: questId,
            properties: {'source': 'user'},
          ),
    );
  }

  void setToday(String questId, String missionId) {
    final changed = <Mission>[];
    state = [
      for (final mission in state)
        if (mission.questId == questId)
          () {
            final updated = mission.copyWith(isToday: mission.id == missionId);
            if (updated.isToday != mission.isToday) changed.add(updated);
            return updated;
          }()
        else
          mission,
    ];
    for (final mission in changed) {
      unawaited(
        _persistMission(
          mission,
          sourceType: ArcMemorySourceType.missionCreated,
          recordJourney: false,
        ),
      );
    }
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
      progressPercent: 100,
    );
    state = [
      for (final mission in state)
        if (mission.id == missionId) updatedMission else mission,
    ];
    _syncQuestProgress(updatedMission.questId);
    _recordMissionEmotion(
      updatedMission,
      trigger: ArcActionTrigger.missionCompleted,
    );
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .missionCompleted(
            userId: ref.read(authControllerProvider).profile?.id,
            difficulty: updatedMission.difficulty.name,
            hasQuest: updatedMission.questId.isNotEmpty,
          ),
    );
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .progress(
            name: AnalyticsEventName.missionCompleted,
            userId: ref.read(authControllerProvider).profile?.id,
            questId: updatedMission.questId,
            missionId: updatedMission.id,
            properties: {'status': 'completed'},
            idempotencyKey:
                'mission_completed:${updatedMission.id}:${updatedMission.updatedAt.microsecondsSinceEpoch}',
          ),
    );

    unawaited(
      _persistMission(
        updatedMission,
        sourceType: ArcMemorySourceType.missionCompleted,
      ),
    );
    unawaited(_recordRouteProgressEvent(updatedMission, 'completed'));
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
    final ownerId = ref.read(authControllerProvider).profile?.id;
    if (ownerId == null) {
      state = const [];
      return;
    }
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
      if (ref.read(authControllerProvider).profile?.id != ownerId) return;
      final loadedIds = loaded.map((mission) => mission.id).toSet();
      final questIdSet = questIds.toSet();
      final localOnly = state.where(
        (mission) =>
            questIdSet.contains(mission.questId) &&
            !loadedIds.contains(mission.id),
      );
      state = [...loaded, ...localOnly];
      for (final questId in questIds) {
        _syncQuestProgress(questId);
      }
      sync.saved('Missionを読み込みました。');
    } catch (error) {
      if (ref.read(authControllerProvider).profile?.id != ownerId) return;
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

  void _syncQuestProgress(String questId) {
    final snapshot = const QuestProgressService().calculate(
      state.where((mission) => mission.questId == questId),
    );
    ref
        .read(questControllerProvider.notifier)
        .updateProgress(questId, snapshot.value);
  }

  Future<void> _persistMission(
    Mission mission, {
    required ArcMemorySourceType sourceType,
    bool recordJourney = true,
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
      if (ref.read(authControllerProvider).profile?.id != userId) return;
      state = [
        for (final current in state)
          if (current.id == savedMission.id) savedMission else current,
      ];
      if (recordJourney) {
        unawaited(_saveSupportProfile(savedMission));
        unawaited(_tagMission(userId, savedMission));
        _growBond(sourceType);
        await _rememberMission(savedMission, sourceType);
      }
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

  Future<void> _deleteMission(String missionId) async {
    final sync = ref.read(missionSyncControllerProvider.notifier);
    sync.loading('Missionを削除しています...');
    try {
      await ref.read(missionRepositoryProvider).delete(missionId);
      sync.saved('Missionを削除しました。');
    } catch (error) {
      sync.failed('Mission delete', error);
    }
  }

  Future<void> _saveSupportProfile(Mission mission) async {
    try {
      await ref
          .read(missionSupportProfileRepositoryProvider)
          .save(
            mission.id,
            const MissionSupportClassifier().classify(
              '${mission.title} ${mission.description}',
            ),
          );
    } catch (_) {
      // Support classification is optional and never blocks Mission creation.
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

  Future<void> _recordRouteProgressEvent(
    Mission mission,
    String eventType,
  ) async {
    try {
      await ref
          .read(routeReplanningRepositoryProvider)
          .recordProgressEvent(
            questId: mission.questId,
            missionId: mission.id,
            eventType: eventType,
            eventKey: '$eventType:${mission.id}',
            metadata: {'progressPercent': mission.progressPercent},
          );
    } catch (_) {
      // Route review telemetry must never block Mission completion.
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
