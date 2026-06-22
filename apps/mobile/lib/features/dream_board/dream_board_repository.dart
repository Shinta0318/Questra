import 'dream_board_model.dart';

abstract class DreamBoardRepository {
  Future<List<DreamBoardItem>> findByQuestId(String questId);

  Future<DreamBoardItem> save({
    required String ownerId,
    required DreamBoardItem item,
  });

  Future<void> remove({required String ownerId, required String itemId});
}

class InMemoryDreamBoardRepository implements DreamBoardRepository {
  final List<_OwnedDreamBoardItem> _items = [];

  @override
  Future<List<DreamBoardItem>> findByQuestId(String questId) async {
    return _items
        .where((entry) => entry.item.questId == questId)
        .map((entry) => entry.item)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<DreamBoardItem> save({
    required String ownerId,
    required DreamBoardItem item,
  }) async {
    _items.removeWhere((entry) => entry.item.id == item.id);
    _items.add(_OwnedDreamBoardItem(ownerId, item));
    return item;
  }

  @override
  Future<void> remove({required String ownerId, required String itemId}) async {
    _items.removeWhere(
      (entry) => entry.ownerId == ownerId && entry.item.id == itemId,
    );
  }
}

class _OwnedDreamBoardItem {
  const _OwnedDreamBoardItem(this.ownerId, this.item);

  final String ownerId;
  final DreamBoardItem item;
}
