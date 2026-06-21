import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'arc_emotion_timeline_model.dart';

abstract interface class ArcEmotionTimelineRepository {
  Future<List<ArcEmotionEvent>> findByUser(String userId, {int limit = 20});
  Future<ArcEmotionEvent> save({
    required String ownerId,
    required ArcEmotionEvent event,
  });
}

class InMemoryArcEmotionTimelineRepository
    implements ArcEmotionTimelineRepository {
  final List<_OwnedArcEmotionEvent> _events = [];

  @override
  Future<List<ArcEmotionEvent>> findByUser(
    String userId, {
    int limit = 20,
  }) async {
    final events =
        _events
            .where((entry) => entry.ownerId == userId)
            .map((entry) => entry.event)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return events.take(limit).toList(growable: false);
  }

  @override
  Future<ArcEmotionEvent> save({
    required String ownerId,
    required ArcEmotionEvent event,
  }) async {
    _events.removeWhere((entry) => entry.event.id == event.id);
    _events.insert(0, _OwnedArcEmotionEvent(ownerId: ownerId, event: event));
    return event;
  }
}

class SupabaseArcEmotionTimelineRepository
    implements ArcEmotionTimelineRepository {
  const SupabaseArcEmotionTimelineRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<ArcEmotionEvent>> findByUser(
    String userId, {
    int limit = 20,
  }) async {
    final rows = await client
        .from('arc_emotion_events')
        .select(
          'id,emotion,source_type,reason,source_id,quest_id,mission_id,trail_id,created_at',
        )
        .eq('owner_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<ArcEmotionEvent> save({
    required String ownerId,
    required ArcEmotionEvent event,
  }) async {
    final rows = await client
        .from('arc_emotion_events')
        .upsert(_toRow(ownerId, event))
        .select(
          'id,emotion,source_type,reason,source_id,quest_id,mission_id,trail_id,created_at',
        )
        .limit(1);

    if (rows.isEmpty) {
      throw StateError('Arc emotion event was not saved.');
    }
    return _fromRow(Map<String, dynamic>.from(rows.first));
  }

  Map<String, Object?> _toRow(String ownerId, ArcEmotionEvent event) {
    return {
      'id': event.id,
      'owner_id': ownerId,
      'emotion': event.emotion.name,
      'source_type': event.sourceType.storageKey,
      'reason': event.reason,
      'source_id': event.sourceId,
      'quest_id': event.questId,
      'mission_id': event.missionId,
      'trail_id': event.trailId,
      'created_at': event.createdAt.toIso8601String(),
    };
  }

  ArcEmotionEvent _fromRow(Map<String, dynamic> row) {
    return ArcEmotionEvent(
      id: row['id'] as String,
      emotion: arcEmotionFromStorage(row['emotion'] as String? ?? 'normal'),
      sourceType: arcEmotionSourceTypeFromStorage(
        row['source_type'] as String? ?? 'arc_chat',
      ),
      reason: row['reason'] as String? ?? '',
      sourceId: row['source_id'] as String?,
      questId: row['quest_id'] as String?,
      missionId: row['mission_id'] as String?,
      trailId: row['trail_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

class _OwnedArcEmotionEvent {
  const _OwnedArcEmotionEvent({required this.ownerId, required this.event});

  final String ownerId;
  final ArcEmotionEvent event;
}
