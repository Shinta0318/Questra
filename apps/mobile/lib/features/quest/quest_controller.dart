import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import 'quest_model.dart';
import 'quest_providers.dart';

final questControllerProvider = NotifierProvider<QuestController, List<Quest>>(
  QuestController.new,
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
    final quests = await ref.read(questRepositoryProvider).findByUser(userId);
    state = quests;
  }

  void add(Quest quest) {
    state = [...state, quest];
    unawaited(
      _persistQuest(quest, sourceType: ArcMemorySourceType.questCreated),
    );
  }

  void update(Quest updatedQuest) {
    state = [
      for (final quest in state)
        if (quest.id == updatedQuest.id) updatedQuest else quest,
    ];
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
      return;
    }

    try {
      final savedQuest = await ref
          .read(questRepositoryProvider)
          .save(ownerId: userId, quest: quest);
      state = [
        for (final current in state)
          if (current.id == quest.id) savedQuest else current,
      ];
      unawaited(_rememberQuest(userId, savedQuest, sourceType));
    } catch (_) {
      // Quest sync state is introduced later; keep optimistic local state now.
    }
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
      return;
    }

    try {
      await ref
          .read(questRepositoryProvider)
          .delete(ownerId: userId, questId: questId);
    } catch (_) {
      if (removedQuest != null) {
        state = [removedQuest, ...state];
      }
    }
  }
}
