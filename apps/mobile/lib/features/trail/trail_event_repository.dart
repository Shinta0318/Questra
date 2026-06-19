import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'trail_event_model.dart';

abstract interface class TrailEventRepository {
  Future<List<TrailEvent>> findByTrail(String trailId);
  Future<TrailEvent> save(TrailEvent event);
}

class InMemoryTrailEventRepository implements TrailEventRepository {
  final List<TrailEvent> _events = [];

  @override
  Future<List<TrailEvent>> findByTrail(String trailId) async {
    return _events
        .where((event) => event.trailId == trailId)
        .toList(growable: false);
  }

  @override
  Future<TrailEvent> save(TrailEvent event) async {
    _events.removeWhere((current) => current.id == event.id);
    _events.insert(0, event);
    return event;
  }
}

class SupabaseTrailEventRepository implements TrailEventRepository {
  const SupabaseTrailEventRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<TrailEvent>> findByTrail(String trailId) async {
    final rows = await client
        .from('trail_events')
        .select()
        .eq('trail_id', trailId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => _eventFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<TrailEvent> save(TrailEvent event) async {
    final rows = await client
        .from('trail_events')
        .upsert(_eventToRow(event))
        .select()
        .limit(1);

    if (rows.isEmpty) {
      throw StateError('Trail event was not saved.');
    }

    return _eventFromRow(Map<String, dynamic>.from(rows.first));
  }

  Map<String, Object?> _eventToRow(TrailEvent event) {
    return {
      'id': event.id,
      'trail_id': event.trailId,
      'quest_id': event.questId,
      'mission_id': event.missionId,
      'event_type': event.eventType.storageKey,
      'content': event.content,
      'metadata': event.metadata,
      'created_at': event.createdAt.toIso8601String(),
    };
  }

  TrailEvent _eventFromRow(Map<String, dynamic> row) {
    return TrailEvent(
      id: row['id'] as String,
      trailId: row['trail_id'] as String,
      questId: row['quest_id'] as String?,
      missionId: row['mission_id'] as String?,
      eventType: trailEventTypeFromStorage(row['event_type'] as String),
      content: row['content'] as String? ?? '',
      metadata: Map<String, Object?>.from(row['metadata'] as Map? ?? {}),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
