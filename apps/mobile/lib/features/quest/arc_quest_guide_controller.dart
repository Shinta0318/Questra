import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import '../../core/persistence/persistence_sync_state.dart';
import '../../core/safety/quest_safety_service.dart';
import '../../core/safety/safety_providers.dart';
import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import 'arc_quest_guide_service.dart';
import '../mission/mission_controller.dart';
import '../task/task_controller.dart';
import '../task/task_load_state.dart';
import 'planning_preferences_controller.dart';
import 'planning_cooldown_repository.dart';
import 'quest_model.dart';

final arcQuestGuideServiceProvider = Provider<ArcQuestGuideService>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseArcQuestGuideService(client: Supabase.instance.client);
  }
  return const LocalArcQuestGuideService();
});

final arcQuestGuideControllerProvider =
    NotifierProvider<ArcQuestGuideController, ArcQuestGuideState>(
      ArcQuestGuideController.new,
    );

class ArcQuestGuideState {
  const ArcQuestGuideState({
    this.guidesByQuest = const {},
    this.loadingQuestIds = const {},
    this.errorsByQuest = const {},
    this.clarificationQuestionsByQuest = const {},
    this.retryAfterByQuest = const {},
  });

  final Map<String, ArcQuestGuide> guidesByQuest;
  final Set<String> loadingQuestIds;
  final Map<String, String> errorsByQuest;
  final Map<String, List<String>> clarificationQuestionsByQuest;
  final Map<String, DateTime> retryAfterByQuest;

  ArcQuestGuide? guideFor(String questId) => guidesByQuest[questId];

  bool isLoading(String questId) => loadingQuestIds.contains(questId);

  String? errorFor(String questId) => errorsByQuest[questId];

  List<String> clarificationQuestionsFor(String questId) =>
      clarificationQuestionsByQuest[questId] ?? const [];

  DateTime? retryAfterFor(String questId) => retryAfterByQuest[questId];

  ArcQuestGuideState copyWith({
    Map<String, ArcQuestGuide>? guidesByQuest,
    Set<String>? loadingQuestIds,
    Map<String, String>? errorsByQuest,
    Map<String, List<String>>? clarificationQuestionsByQuest,
    Map<String, DateTime>? retryAfterByQuest,
  }) {
    return ArcQuestGuideState(
      guidesByQuest: guidesByQuest ?? this.guidesByQuest,
      loadingQuestIds: loadingQuestIds ?? this.loadingQuestIds,
      errorsByQuest: errorsByQuest ?? this.errorsByQuest,
      clarificationQuestionsByQuest:
          clarificationQuestionsByQuest ?? this.clarificationQuestionsByQuest,
      retryAfterByQuest: retryAfterByQuest ?? this.retryAfterByQuest,
    );
  }
}

class ArcQuestGuideController extends Notifier<ArcQuestGuideState> {
  @override
  ArcQuestGuideState build() {
    ref.watch(authControllerProvider.select((auth) => auth.profile?.id));
    return const ArcQuestGuideState();
  }

  Future<void> hydrateCooldownForQuest(String questId) async {
    await _restoreCooldown(questId);
  }

  Future<DateTime?> _restoreCooldown(String questId) async {
    final ownerId = ref.read(authControllerProvider).profile?.id;
    if (ownerId == null) return null;
    try {
      final retryAt = await ref
          .read(planningCooldownRepositoryProvider)
          .load(ownerId, questId);
      if (ref.read(authControllerProvider).profile?.id != ownerId ||
          retryAt == null ||
          !retryAt.isAfter(DateTime.now())) {
        return null;
      }
      state = state.copyWith(
        retryAfterByQuest: {...state.retryAfterByQuest, questId: retryAt},
      );
      return retryAt;
    } catch (_) {
      return null;
    }
  }

  Future<void> generateForQuest(
    Quest quest, {
    Map<String, String> clarificationAnswers = const {},
  }) async {
    if (state.isLoading(quest.id) ||
        (state.retryAfterFor(quest.id)?.isAfter(DateTime.now()) ?? false)) {
      return;
    }
    if (await _restoreCooldown(quest.id) != null || state.isLoading(quest.id)) {
      return;
    }
    final ownerId = ref.read(authControllerProvider).profile?.id;

    state = state.copyWith(
      loadingQuestIds: {...state.loadingQuestIds, quest.id},
      errorsByQuest: {...state.errorsByQuest}..remove(quest.id),
      retryAfterByQuest: {...state.retryAfterByQuest}..remove(quest.id),
    );

    try {
      final planning = ref.read(planningPreferencesControllerProvider);
      if (clarificationAnswers.isNotEmpty &&
          !planning.contextForPlanning.consentGranted) {
        state = state.copyWith(
          loadingQuestIds: {...state.loadingQuestIds}..remove(quest.id),
          errorsByQuest: {
            ...state.errorsByQuest,
            quest.id: '追加回答はまだ送信していません。Arcの航路設計に使う条件を確認してください。',
          },
        );
        return;
      }
      final safety = await ref
          .read(questSafetyServiceProvider)
          .assess(planningWishWithAnswers(quest, clarificationAnswers));
      if (ref.read(authControllerProvider).profile?.id != ownerId) return;
      if (safety.action != QuestSafetyAction.allow) {
        unawaited(
          ref
              .read(safetySignalRecorderProvider)
              .record(
                userId: ref.read(authControllerProvider).profile?.id,
                assessment: safety,
              ),
        );
        state = state.copyWith(
          loadingQuestIds: {...state.loadingQuestIds}..remove(quest.id),
          errorsByQuest: {...state.errorsByQuest, quest.id: safety.userMessage},
        );
        return;
      }
      final guide = await ref
          .read(arcQuestGuideServiceProvider)
          .generate(
            quest: quest,
            planningContext: planning.contextForPlanning,
            clarificationAnswers: clarificationAnswers,
          );
      if (ref.read(authControllerProvider).profile?.id != ownerId) return;
      state = state.copyWith(
        guidesByQuest: {...state.guidesByQuest, quest.id: guide},
        loadingQuestIds: {...state.loadingQuestIds}..remove(quest.id),
        clarificationQuestionsByQuest: {...state.clarificationQuestionsByQuest}
          ..remove(quest.id),
        retryAfterByQuest: {...state.retryAfterByQuest}..remove(quest.id),
      );
      if (ownerId != null) {
        try {
          await ref
              .read(planningCooldownRepositoryProvider)
              .clear(ownerId, quest.id);
        } catch (_) {
          // Successful planning stays available if local storage is unavailable.
        }
      }
      unawaited(_rememberGuide(quest, guide));
    } catch (error) {
      if (ref.read(authControllerProvider).profile?.id != ownerId) return;
      if (error is PlanningClarificationException) {
        state = state.copyWith(
          loadingQuestIds: {...state.loadingQuestIds}..remove(quest.id),
          errorsByQuest: {...state.errorsByQuest}..remove(quest.id),
          clarificationQuestionsByQuest: {
            ...state.clarificationQuestionsByQuest,
            quest.id: error.questions,
          },
        );
        return;
      }
      final retryAt = error is PlanningRateLimitException
          ? DateTime.now().add(error.retryAfter)
          : null;
      final cooldowns = {...state.retryAfterByQuest};
      if (retryAt != null) cooldowns[quest.id] = retryAt;
      state = state.copyWith(
        loadingQuestIds: {...state.loadingQuestIds}..remove(quest.id),
        retryAfterByQuest: cooldowns,
        errorsByQuest: {
          ...state.errorsByQuest,
          quest.id: error is StateError
              ? error.message.toString()
              : error.toString(),
        },
      );
      if (ownerId != null && retryAt != null) {
        try {
          await ref
              .read(planningCooldownRepositoryProvider)
              .save(ownerId, quest.id, retryAt);
        } catch (_) {
          // Keep the active-screen cooldown even if durable storage fails.
        }
      }
    }
  }

  Future<bool> approveForQuest(
    Quest quest,
    ArcQuestGuide guide,
    List<ArcMissionCandidate> candidates,
  ) async {
    if (candidates.isEmpty) throw StateError('確定できるMission候補がありません。');
    final ownerId = ref.read(authControllerProvider).profile?.id;
    await ref
        .read(arcQuestGuideServiceProvider)
        .approve(guide: guide, candidates: candidates);
    if (ref.read(authControllerProvider).profile?.id != ownerId) return false;
    if (identical(state.guidesByQuest[quest.id], guide)) {
      state = state.copyWith(
        guidesByQuest: {...state.guidesByQuest}..remove(quest.id),
        errorsByQuest: {...state.errorsByQuest}..remove(quest.id),
      );
    }
    unawaited(_rememberGuide(quest, guide));
    try {
      await ref.read(missionControllerProvider.notifier).loadForQuests([
        quest.id,
      ]);
      await ref.read(taskControllerProvider.notifier).loadForQuestIds([
        quest.id,
      ]);
      return ref.read(authControllerProvider).profile?.id == ownerId &&
          ref.read(missionSyncControllerProvider).status ==
              PersistenceSyncStatus.idle &&
          ref.read(taskLoadStateProvider).status == TaskLoadStatus.loaded;
    } catch (_) {
      return false;
    }
  }

  Future<void> rejectForQuest(Quest quest, ArcQuestGuide guide) async {
    final ownerId = ref.read(authControllerProvider).profile?.id;
    await ref.read(arcQuestGuideServiceProvider).reject(guide);
    if (ref.read(authControllerProvider).profile?.id != ownerId ||
        !identical(state.guidesByQuest[quest.id], guide)) {
      return;
    }
    state = state.copyWith(
      guidesByQuest: {...state.guidesByQuest}..remove(quest.id),
      errorsByQuest: {...state.errorsByQuest}..remove(quest.id),
    );
  }

  void acceptGeneratedGuide(Quest quest, ArcQuestGuide guide) {
    state = state.copyWith(
      guidesByQuest: {...state.guidesByQuest, quest.id: guide},
      loadingQuestIds: {...state.loadingQuestIds}..remove(quest.id),
      errorsByQuest: {...state.errorsByQuest}..remove(quest.id),
      clarificationQuestionsByQuest: {...state.clarificationQuestionsByQuest}
        ..remove(quest.id),
    );
    unawaited(_rememberGuide(quest, guide));
  }

  Future<void> _rememberGuide(Quest quest, ArcQuestGuide guide) async {
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
              questId: quest.id,
              sourceId: quest.id,
              sourceType: ArcMemorySourceType.questUpdated,
              title: 'Arcガイドを生成',
              text:
                  '${guide.summary}\n${guide.path}\n'
                  '${guide.missionCandidates.map((candidate) => candidate.title).join(' / ')}',
              metadata: {
                'source': guide.sourceType,
                'mission_candidate_count': guide.missionCandidates.length,
              },
            ),
          );
      ref.invalidate(visibleArcMemoriesProvider);
    } catch (_) {
      // Keep the generated guide available even if memory sync is unavailable.
    }
  }
}
