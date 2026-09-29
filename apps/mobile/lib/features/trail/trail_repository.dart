import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/performance/performance_limits.dart';
import 'trail_model.dart';

abstract interface class TrailRepository {
  Future<List<Trail>> findByUser(
    String userId, {
    int limit = QuestraPerformanceLimits.trailListLimit,
    TrailPageCursor? before,
  });
  Future<Trail> save({
    required String ownerId,
    required Trail trail,
    String visibility,
  });
  Future<void> delete({required String ownerId, required String trailId});
}

class TrailPageCursor {
  const TrailPageCursor({required this.createdAt, required this.id});

  factory TrailPageCursor.fromTrail(Trail trail) {
    return TrailPageCursor(createdAt: trail.createdAt, id: trail.id);
  }

  final DateTime createdAt;
  final String id;
}

class InMemoryTrailRepository implements TrailRepository {
  final List<_OwnedTrail> _trails = [];

  @override
  Future<List<Trail>> findByUser(
    String userId, {
    int limit = QuestraPerformanceLimits.trailListLimit,
    TrailPageCursor? before,
  }) async {
    final trails =
        _trails
            .where((entry) => entry.ownerId == userId)
            .map((entry) => entry.trail)
            .where((trail) => _isBeforeCursor(trail, before))
            .toList(growable: false)
          ..sort((a, b) {
            final created = b.createdAt.compareTo(a.createdAt);
            return created == 0 ? b.id.compareTo(a.id) : created;
          });
    return trails.take(limit).toList(growable: false);
  }

  @override
  Future<Trail> save({
    required String ownerId,
    required Trail trail,
    String visibility = 'private',
  }) async {
    _trails.removeWhere(
      (entry) => entry.ownerId == ownerId && entry.trail.id == trail.id,
    );
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
  Future<List<Trail>> findByUser(
    String userId, {
    int limit = QuestraPerformanceLimits.trailListLimit,
    TrailPageCursor? before,
  }) async {
    var query = client
        .from('trails')
        .select(
          'id,quest_id,mission_id,task_id,title,summary,content,trail_type,source_type,created_at',
        )
        .eq('owner_id', userId);
    if (before != null) {
      final createdAt = before.createdAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$createdAt,and(created_at.eq.$createdAt,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);

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
        .select(
          'id,quest_id,mission_id,task_id,title,summary,content,trail_type,source_type,created_at',
        )
        .limit(1);

    if (rows.isEmpty) {
      throw StateError('Trail was not saved.');
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
      'task_id': trail.taskId,
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
      taskId: row['task_id'] as String?,
      title: row['title'] as String,
      summary: row['summary'] as String? ?? '',
      content: row['content'] as String? ?? '',
      trailType: trailTypeFromStorage(row['trail_type'] as String),
      sourceType: row['source_type'] as String? ?? 'trail',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

bool _isBeforeCursor(Trail trail, TrailPageCursor? cursor) {
  if (cursor == null) return true;
  final createdComparison = trail.createdAt.compareTo(cursor.createdAt);
  if (createdComparison != 0) return createdComparison < 0;
  return trail.id.compareTo(cursor.id) < 0;
}

class _OwnedTrail {
  const _OwnedTrail({required this.ownerId, required this.trail});

  final String ownerId;
  final Trail trail;
}
