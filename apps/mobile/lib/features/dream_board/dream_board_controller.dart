import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'dream_board_model.dart';
import 'dream_board_repository.dart';

final dreamBoardRepositoryProvider = Provider<DreamBoardRepository>((ref) {
  return InMemoryDreamBoardRepository();
});

final dreamBoardControllerProvider =
    NotifierProvider<DreamBoardController, Map<String, List<DreamBoardItem>>>(
      DreamBoardController.new,
    );

class DreamBoardController extends Notifier<Map<String, List<DreamBoardItem>>> {
  static const localOwnerId = 'local-dream-board';

  @override
  Map<String, List<DreamBoardItem>> build() {
    return const {};
  }

  Future<void> loadForQuest(String questId) async {
    final items = await ref
        .read(dreamBoardRepositoryProvider)
        .findByQuestId(questId);
    state = {...state, questId: items};
  }

  Future<void> addItem({
    required String questId,
    required String title,
    required String note,
    required DreamBoardItemType itemType,
    String? imageUrl,
    String? sourceUrl,
    Map<String, Object?> metadata = const {},
  }) async {
    final item = DreamBoardItem(
      questId: questId,
      title: title,
      note: note,
      itemType: itemType,
      imageUrl: imageUrl,
      sourceUrl: sourceUrl,
      metadata: metadata,
    );

    _merge(item);
    unawaited(_save(item));
  }

  Future<void> removeItem(DreamBoardItem item) async {
    final current = state[item.questId] ?? const <DreamBoardItem>[];
    state = {
      ...state,
      item.questId: current.where((entry) => entry.id != item.id).toList(),
    };

    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? localOwnerId;
    unawaited(
      ref
          .read(dreamBoardRepositoryProvider)
          .remove(ownerId: ownerId, itemId: item.id),
    );
  }

  void _merge(DreamBoardItem item) {
    final current = state[item.questId] ?? const <DreamBoardItem>[];
    final next = [item, ...current.where((entry) => entry.id != item.id)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = {...state, item.questId: next};
  }

  Future<void> _save(DreamBoardItem item) async {
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? localOwnerId;
    try {
      final saved = await ref
          .read(dreamBoardRepositoryProvider)
          .save(ownerId: ownerId, item: item);
      _merge(saved);
    } catch (_) {
      // Dream Board is inspiration metadata; keep optimistic local state visible.
    }
  }
}
