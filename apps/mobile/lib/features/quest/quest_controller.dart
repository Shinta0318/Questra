import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/persistence/persistence_sync_state.dart';
import '../arc/arc_action_trigger_service.dart';
import '../arc/arc_bond_growth_service.dart';
import '../arc/arc_emotion_timeline_controller.dart';
import '../arc/arc_guidance_providers.dart';
import '../arc/stardust_service.dart';
import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import '../tagging/tagging_providers.dart';
import 'quest_model.dart';
import 'quest_providers.dart';

final questControllerProvider = NotifierProvider<QuestController, List<Quest>>(
  QuestController.new,
);

final questSyncControllerProvider =
    NotifierProvider<PersistenceSyncController, PersistenceSyncState>(
      PersistenceSyncController.new,
    );

class QuestController extends Notifier<List<Quest>> {
  @override
  List<Quest> build() {
    final initialUserId = ref.read(authControllerProvider).profile?.id;
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (next == previous) return;
      state = const [];
      if (next != null) unawaited(loadForUser(next));
    });

    if (initialUserId != null) {
      unawaited(Future<void>.microtask(() => loadForUser(initialUserId)));
    }

    return const [];
  }

  Quest? findById(String id) {
    for (final quest in state) {
      if (quest.id == id) {
        return quest;
      }
    }
    return null;
  }

  Future<void> loadForUser(String userId) async {
    if (ref.read(authControllerProvider).profile?.id != userId) return;
    final sync = ref.read(questSyncControllerProvider.notifier);
    sync.loading('Questを読み込んでいます...');
    try {
      final quests = await ref.read(questRepositoryProvider).findByUser(userId);
      if (ref.read(authControllerProvider).profile?.id != userId) return;
      state = quests;
      sync.saved('Questを読み込みました。');
    } catch (error) {
      if (ref.read(authControllerProvider).profile?.id != userId) return;
      sync.failed('Questの読み込み', error);
    }
  }

  void add(Quest quest) {
    state = [...state, quest];
    _recordQuestAction(ArcActionTrigger.questCreated, quest);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .questCreated(
            userId: ref.read(authControllerProvider).profile?.id,
            questId: quest.id,
            category: quest.category,
            difficulty: quest.difficulty.storageKey,
            visibility: quest.visibility.storageKey,
          ),
    );
    unawaited(
      _persistQuest(quest, sourceType: ArcMemorySourceType.questCreated),
    );
  }

  void update(Quest updatedQuest) {
    state = [
      for (final quest in state)
        if (quest.id == updatedQuest.id) updatedQuest else quest,
    ];
    _recordQuestAction(ArcActionTrigger.questUpdated, updatedQuest);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .progress(
            name: AnalyticsEventName.questUpdated,
            userId: ref.read(authControllerProvider).profile?.id,
            questId: updatedQuest.id,
            properties: {
              'status': updatedQuest.status.storageKey,
              'progress_band': _progressBand(updatedQuest.progress),
            },
          ),
    );
    unawaited(
      _persistQuest(updatedQuest, sourceType: ArcMemorySourceType.questUpdated),
    );
  }

  void updateProgress(String questId, double progress) {
    final quest = findById(questId);
    if (quest == null) return;
    final normalized = progress.clamp(0.0, 1.0);
    if ((quest.progress - normalized).abs() < 0.0001) return;
    final updatedQuest = quest.copyWith(progress: normalized);
    state = [
      for (final current in state)
        if (current.id == questId) updatedQuest else current,
    ];
    unawaited(
      _persistQuest(
        updatedQuest,
        sourceType: ArcMemorySourceType.questUpdated,
        recordJourney: false,
      ),
    );
  }

  void remove(String id) {
    final removedQuest = findById(id);
    state = state.where((quest) => quest.id != id).toList();
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .progress(
            name: AnalyticsEventName.questDeleted,
            userId: ref.read(authControllerProvider).profile?.id,
            questId: id,
            properties: {'source': 'quest_controller'},
          ),
    );
    unawaited(_deleteQuest(id, removedQuest));
  }

  String _progressBand(double progress) {
    if (progress <= 0) return 'not_started';
    if (progress < 0.5) return 'early';
    if (progress < 0.8) return 'middle';
    if (progress < 1) return 'near_completion';
    return 'completed';
  }

  Future<void> _persistQuest(
    Quest quest, {
    required ArcMemorySourceType sourceType,
    bool recordJourney = true,
  }) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      ref
          .read(questSyncControllerProvider.notifier)
          .failed('Quest save', 'ログインが必要です。');
      if (recordJourney) {
        _recordQuestAction(
          ArcActionTrigger.unauthenticated,
          quest,
          surface: 'Quest保存',
        );
      }
      return;
    }

    final sync = ref.read(questSyncControllerProvider.notifier);
    sync.loading('Questを保存しています...');
    try {
      final savedQuest = await ref
          .read(questRepositoryProvider)
          .save(ownerId: userId, quest: quest);
      if (ref.read(authControllerProvider).profile?.id != userId) return;
      state = [
        for (final current in state)
          if (current.id == quest.id) savedQuest else current,
      ];
      if (recordJourney) {
        unawaited(_tagQuest(userId, savedQuest));
        _growBond(sourceType);
        unawaited(_rememberQuest(userId, savedQuest, sourceType));
      }
      sync.saved('Questを保存しました。');
    } catch (error) {
      sync.failed('Questの保存', error);
      if (recordJourney) {
        _recordQuestAction(
          ArcActionTrigger.saveFailure,
          quest,
          surface: 'Quest保存',
        );
      }
    }
  }

  void _recordQuestAction(
    ArcActionTrigger trigger,
    Quest quest, {
    String? surface,
  }) {
    final decision = ref
        .read(arcActionTriggerServiceProvider)
        .resolve(trigger: trigger, questTitle: quest.title, surface: surface);
    ref
        .read(arcEmotionTimelineControllerProvider.notifier)
        .record(
          emotion: decision.emotion,
          sourceType: decision.sourceType,
          reason: decision.message,
          sourceId: quest.id,
          questId: quest.id,
        );
  }

  Future<void> _tagQuest(String userId, Quest quest) async {
    try {
      await ref
          .read(taggingServiceProvider)
          .tagQuest(ownerId: userId, quest: quest);
    } catch (_) {
      // Tagging is an enrichment path; keep Quest persistence authoritative.
    }
  }

  void _growBond(ArcMemorySourceType sourceType) {
    final growth = ref.read(arcBondGrowthServiceProvider).forQuest(sourceType);
    final award = ref.read(stardustServiceProvider).forQuest(sourceType);
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

  Future<void> _rememberQuest(
    String userId,
    Quest quest,
    ArcMemorySourceType sourceType,
  ) async {
    try {
      await ref
          .read(memoryExtractionServiceProvider)
          .extractAndSave(
            MemoryExtractionEvent(
              userId: userId,
              questId: quest.id,
              sourceId: quest.id,
              sourceType: sourceType,
              title: 'Questの記憶',
              text: '${quest.title}: ${quest.description}',
              metadata: {'status': quest.status.storageKey},
            ),
          );
      ref.invalidate(visibleArcMemoriesProvider);
    } catch (_) {
      // Arc Memory sync state is introduced later; keep the Quest action.
    }
  }

  Future<void> _deleteQuest(String questId, Quest? removedQuest) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      ref
          .read(questSyncControllerProvider.notifier)
          .failed('Quest delete', 'ログインが必要です。');
      return;
    }

    final sync = ref.read(questSyncControllerProvider.notifier);
    sync.loading('Questを削除しています...');
    try {
      await ref
          .read(questRepositoryProvider)
          .delete(ownerId: userId, questId: questId);
      sync.saved('Questを削除しました。');
    } catch (error) {
      if (removedQuest != null) {
        state = [removedQuest, ...state];
      }
      sync.failed('Questの削除', error);
    }
  }
}
