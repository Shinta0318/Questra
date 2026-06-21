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
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        loadForUser(next);
      }
    });

    return [
      Quest(
        title: 'Design the first adventure arc',
        description: 'Shape the first Questra journey with Arc.',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
        progress: 0.42,
        category: '世界観づくり',
        targetDate: DateTime.now().add(const Duration(days: 7)),
      ),
      Quest(
        title: 'Invite first guild member',
        description: 'Prepare the first lightweight guild loop.',
        difficulty: QuestDifficulty.easy,
        status: QuestStatus.draft,
        visibility: QuestVisibility.guild,
        progress: 0.16,
        category: 'コミュニティ',
      ),
      Quest(
        title: 'Build a morning training ritual',
        description: 'Create a small repeatable routine for real progress.',
        difficulty: QuestDifficulty.hard,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
        progress: 0.68,
        category: 'トレーニング',
      ),
    ];
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
    final sync = ref.read(questSyncControllerProvider.notifier);
    sync.loading('Questを読み込んでいます...');
    try {
      final quests = await ref.read(questRepositoryProvider).findByUser(userId);
      state = quests;
      sync.saved('Questを読み込みました。');
    } catch (error) {
      sync.failed('Quest load', error);
    }
  }

  void add(Quest quest) {
    state = [...state, quest];
    _recordQuestAction(ArcActionTrigger.questCreated, quest);
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
      _persistQuest(updatedQuest, sourceType: ArcMemorySourceType.questUpdated),
    );
  }

  void remove(String id) {
    final removedQuest = findById(id);
    state = state.where((quest) => quest.id != id).toList();
    unawaited(_deleteQuest(id, removedQuest));
  }

  Future<void> _persistQuest(
    Quest quest, {
    required ArcMemorySourceType sourceType,
  }) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      ref
          .read(questSyncControllerProvider.notifier)
          .failed('Quest save', 'ログインが必要です。');
      _recordQuestAction(
        ArcActionTrigger.unauthenticated,
        quest,
        surface: 'Quest保存',
      );
      return;
    }

    final sync = ref.read(questSyncControllerProvider.notifier);
    sync.loading('Questを保存しています...');
    try {
      final savedQuest = await ref
          .read(questRepositoryProvider)
          .save(ownerId: userId, quest: quest);
      state = [
        for (final current in state)
          if (current.id == quest.id) savedQuest else current,
      ];
      unawaited(_tagQuest(userId, savedQuest));
      _growBond(sourceType);
      unawaited(_rememberQuest(userId, savedQuest, sourceType));
      sync.saved('Questを保存しました。');
    } catch (error) {
      sync.failed('Quest save', error);
      _recordQuestAction(
        ArcActionTrigger.saveFailure,
        quest,
        surface: 'Quest保存',
      );
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
              title: 'Quest memory',
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
      sync.failed('Quest delete', error);
    }
  }
}
