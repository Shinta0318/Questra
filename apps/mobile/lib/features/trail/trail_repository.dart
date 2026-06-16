import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'trail_model.dart';

abstract interface class TrailRepository {
  Future<List<Trail>> findByUser(String userId);
  Future<Trail> save({
    required String ownerId,
    required Trail trail,
    String visibility,
  });
  Future<void> delete({required String ownerId, required String trailId});
}

class InMemoryTrailRepository implements TrailRepository {
  final List<_OwnedTrail> _trails = [];

  @override
  Future<List<Trail>> findByUser(String userId) async {
    return _trails
        .where((entry) => entry.ownerId == userId)
        .map((entry) => entry.trail)
        .toList(growable: false);
  }

  @override
  Future<Trail> save({
    required String ownerId,
    required Trail trail,
    String visibility = 'private',
  }) async {
    _trails.removeWhere((entry) => entry.trail.id == trail.id);
    _trails.insert(0, _OwnedTrail(ownerId: ownerId, trail: trail));
    return trail;
  }

  @override
  Future<void> delete({
    required String ownerId,
    required String trailId,
  }) async {
    _trails.removeWhere(
      (entry) => entry.ownerId == ownerId && entry.trail.id == trailId,
    );
  }
}

class SupabaseTrailRepository implements TrailRepository {
  const SupabaseTrailRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<Trail>> findByUser(String userId) async {
    final rows = await client
        .from('trails')
        .select()
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => _trailFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<Trail> save({
    required String ownerId,
    required Trail trail,
    String visibility = 'private',
  }) async {
    final rows = await client
        .from('trails')
        .upsert(_trailToRow(ownerId, trail, visibility))
        .select()
        .limit(1);

    if (rows.isEmpty) {
      return trail;
    }

    return _trailFromRow(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<void> delete({
    required String ownerId,
    required String trailId,
  }) async {
    await client
        .from('trails')
        .delete()
        .eq('owner_id', ownerId)
        .eq('id', trailId);
  }

  Map<String, Object?> _trailToRow(
    String ownerId,
    Trail trail,
    String visibility,
  ) {
    return {
      'id': trail.id,
      'owner_id': ownerId,
      'quest_id': trail.questId,
      'mission_id': trail.missionId,
      'title': trail.title,
      'summary': trail.summary,
      'content': trail.content,
      'visibility': visibility,
      'trail_type': trail.trailType.storageKey,
      'source_type': trail.sourceType,
      'created_at': trail.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Trail _trailFromRow(Map<String, dynamic> row) {
    return Trail(
      id: row['id'] as String,
      questId: row['quest_id'] as String?,
      missionId: row['mission_id'] as String?,
      title: row['title'] as String,
      summary: row['summary'] as String? ?? '',
      content: row['content'] as String? ?? '',
      trailType: trailTypeFromStorage(row['trail_type'] as String),
      sourceType: row['source_type'] as String? ?? 'trail',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

class _OwnedTrail {
  const _OwnedTrail({required this.ownerId, required this.trail});

  final String ownerId;
  final Trail trail;
}
