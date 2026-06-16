import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'quest_model.dart';

abstract interface class QuestRepository {
  Future<List<Quest>> findByUser(String userId);
  Future<Quest> save({required String ownerId, required Quest quest});
  Future<void> delete({required String ownerId, required String questId});
}

class InMemoryQuestRepository implements QuestRepository {
  final List<_OwnedQuest> _quests = [];

  @override
  Future<List<Quest>> findByUser(String userId) async {
    return _quests
        .where((entry) => entry.ownerId == userId)
        .map((entry) => entry.quest)
        .toList(growable: false);
  }

  @override
  Future<Quest> save({required String ownerId, required Quest quest}) async {
    _quests.removeWhere((entry) => entry.quest.id == quest.id);
    _quests.add(_OwnedQuest(ownerId: ownerId, quest: quest));
    return quest;
  }

  @override
  Future<void> delete({
    required String ownerId,
    required String questId,
  }) async {
    _quests.removeWhere(
      (entry) => entry.ownerId == ownerId && entry.quest.id == questId,
    );
  }
}

class SupabaseQuestRepository implements QuestRepository {
  const SupabaseQuestRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<Quest>> findByUser(String userId) async {
    final rows = await client
        .from('quests')
        .select()
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => _questFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<Quest> save({required String ownerId, required Quest quest}) async {
    final rows = await client
        .from('quests')
        .upsert(_questToRow(ownerId, quest))
        .select()
        .limit(1);

    if (rows.isEmpty) {
      throw StateError('Quest was not saved.');
    }

    return _questFromRow(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<void> delete({
    required String ownerId,
    required String questId,
  }) async {
    await client
        .from('quests')
        .delete()
        .eq('owner_id', ownerId)
        .eq('id', questId);
  }

  Map<String, Object?> _questToRow(String ownerId, Quest quest) {
    return {
      'id': quest.id,
      'owner_id': ownerId,
      'title': quest.title,
      'description': quest.description,
      'difficulty': quest.difficulty.storageKey,
      'status': quest.status.storageKey,
      'visibility': quest.visibility.storageKey,
      'target_date': quest.targetDate?.toIso8601String().split('T').first,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Quest _questFromRow(Map<String, dynamic> row) {
    return Quest(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      difficulty: questDifficultyFromStorage(row['difficulty'] as String),
      status: questStatusFromStorage(row['status'] as String),
      visibility: questVisibilityFromStorage(row['visibility'] as String),
      targetDate: row['target_date'] == null
          ? null
          : DateTime.parse(row['target_date'] as String),
    );
  }
}

class _OwnedQuest {
  const _OwnedQuest({required this.ownerId, required this.quest});

  final String ownerId;
  final Quest quest;
}
