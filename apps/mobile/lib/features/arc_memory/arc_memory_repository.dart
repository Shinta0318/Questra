import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/performance/performance_limits.dart';
import 'arc_memory_model.dart';

abstract interface class ArcMemoryRepository {
  Future<List<ArcMemory>> findByUser(
    String userId, {
    int limit = QuestraPerformanceLimits.arcMemoryVisibleLimit,
  });
  Future<bool> existsByDedupeKey(String dedupeKey);
  Future<void> save(ArcMemory memory);
}

class InMemoryArcMemoryRepository implements ArcMemoryRepository {
  final List<ArcMemory> _memories = [];

  @override
  Future<List<ArcMemory>> findByUser(
    String userId, {
    int limit = QuestraPerformanceLimits.arcMemoryVisibleLimit,
  }) async {
    final memories =
        _memories
            .where((memory) => memory.userId == userId)
            .where((memory) => memory.userVisible)
            .toList()
          ..sort((a, b) {
            final importance = b.importanceScore.compareTo(a.importanceScore);
            if (importance != 0) {
              return importance;
            }
            return b.createdAt.compareTo(a.createdAt);
          });

    return memories.take(limit).toList(growable: false);
  }

  @override
  Future<bool> existsByDedupeKey(String dedupeKey) async {
    return _memories.any((memory) => memory.dedupeKey == dedupeKey);
  }

  @override
  Future<void> save(ArcMemory memory) async {
    _memories.add(memory);
  }
}

class SupabaseArcMemoryRepository implements ArcMemoryRepository {
  const SupabaseArcMemoryRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<ArcMemory>> findByUser(
    String userId, {
    int limit = QuestraPerformanceLimits.arcMemoryVisibleLimit,
  }) async {
    final rows = await client
        .from('arc_memories')
        .select(
          'id,user_id,quest_id,mission_id,trail_id,memory_type,title,content,importance_score,emotional_tone,source_type,source_id,metadata,sensitivity_level,user_visible,created_at,updated_at',
        )
        .eq('user_id', userId)
        .eq('user_visible', true)
        .order('importance_score', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .map((row) => _memoryFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<bool> existsByDedupeKey(String dedupeKey) async {
    final rows = await client
        .from('arc_memories')
        .select('id')
        .eq('metadata->>dedupe_key', dedupeKey)
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<void> save(ArcMemory memory) async {
    await client.from('arc_memories').insert(_memoryToRow(memory));
  }

  Map<String, Object?> _memoryToRow(ArcMemory memory) {
    return {
      'id': memory.id,
      'user_id': memory.userId,
      'quest_id': memory.questId,
      'mission_id': memory.missionId,
      'trail_id': memory.trailId,
      'memory_type': memory.memoryType.storageKey,
      'title': memory.title,
      'content': memory.content,
      'importance_score': memory.importanceScore,
      'emotional_tone': memory.emotionalTone.storageKey,
      'source_type': memory.sourceType.storageKey,
      'source_id': memory.sourceId,
      'embedding': memory.embedding,
      'metadata': {...memory.metadata, 'dedupe_key': memory.dedupeKey},
      'sensitivity_level': memory.sensitivityLevel.storageKey,
      'user_visible': memory.userVisible,
      'created_at': memory.createdAt.toIso8601String(),
      'updated_at': memory.updatedAt.toIso8601String(),
    };
  }

  ArcMemory _memoryFromRow(Map<String, dynamic> row) {
    return ArcMemory(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      questId: row['quest_id'] as String?,
      missionId: row['mission_id'] as String?,
      trailId: row['trail_id'] as String?,
      memoryType: _memoryTypeFromStorage(row['memory_type'] as String),
      title: row['title'] as String,
      content: row['content'] as String,
      importanceScore: (row['importance_score'] as num).toDouble(),
      emotionalTone: _toneFromStorage(row['emotional_tone'] as String),
      sourceType: _sourceTypeFromStorage(row['source_type'] as String),
      sourceId: row['source_id'] as String?,
      embedding: (row['embedding'] as List?)?.cast<double>(),
      metadata: Map<String, Object?>.from(row['metadata'] as Map? ?? {}),
      sensitivityLevel: _sensitivityFromStorage(
        row['sensitivity_level'] as String,
      ),
      userVisible: row['user_visible'] as bool? ?? true,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  ArcMemoryType _memoryTypeFromStorage(String value) {
    return ArcMemoryType.values.firstWhere(
      (type) => type.storageKey == value,
      orElse: () => ArcMemoryType.questMemory,
    );
  }

  ArcMemorySourceType _sourceTypeFromStorage(String value) {
    return ArcMemorySourceType.values.firstWhere(
      (type) => type.storageKey == value,
      orElse: () => ArcMemorySourceType.arcChat,
    );
  }

  EmotionalTone _toneFromStorage(String value) {
    return EmotionalTone.values.firstWhere(
      (tone) => tone.storageKey == value,
      orElse: () => EmotionalTone.neutral,
    );
  }

  SensitivityLevel _sensitivityFromStorage(String value) {
    return SensitivityLevel.values.firstWhere(
      (level) => level.storageKey == value,
      orElse: () => SensitivityLevel.standard,
    );
  }
}
