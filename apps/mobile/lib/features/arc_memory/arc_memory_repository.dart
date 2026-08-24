import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/performance/performance_limits.dart';
import 'arc_memory_model.dart';

abstract interface class ArcMemoryRepository {
  Future<List<ArcMemory>> findByUser(
    String userId, {
    int limit = QuestraPerformanceLimits.arcMemoryVisibleLimit,
  });
  Future<List<ArcMemory>> findForControl(String userId, {int limit = 100});
  Future<bool> existsByDedupeKey(String dedupeKey);
  Future<void> save(ArcMemory memory);
  Future<void> update(ArcMemory memory);
  Future<void> deleteById(String userId, String memoryId);
  Future<void> deleteAllForUser(String userId);
  Future<void> deleteByTaskId(String userId, String taskId);
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
            .where((memory) => !memory.isExpired)
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
  Future<List<ArcMemory>> findForControl(
    String userId, {
    int limit = 100,
  }) async {
    final memories =
        _memories.where((memory) => memory.userId == userId).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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

  @override
  Future<void> update(ArcMemory memory) async {
    final index = _memories.indexWhere(
      (item) => item.id == memory.id && item.userId == memory.userId,
    );
    if (index < 0) throw StateError('Memoryが見つかりません。');
    _memories[index] = memory;
  }

  @override
  Future<void> deleteById(String userId, String memoryId) async {
    _memories.removeWhere(
      (memory) => memory.userId == userId && memory.id == memoryId,
    );
  }

  @override
  Future<void> deleteAllForUser(String userId) async {
    _memories.removeWhere((memory) => memory.userId == userId);
  }

  @override
  Future<void> deleteByTaskId(String userId, String taskId) async {
    _memories.removeWhere(
      (memory) => memory.userId == userId && memory.taskId == taskId,
    );
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
          'id,user_id,quest_id,mission_id,task_id,trail_id,memory_type,title,content,importance_score,emotional_tone,source_type,source_id,metadata,provenance,sensitivity_level,user_visible,retention_until,created_at,updated_at',
        )
        .eq('user_id', userId)
        .eq('user_visible', true)
        .or(
          'retention_until.is.null,retention_until.gt.${DateTime.now().toUtc().toIso8601String()}',
        )
        .order('importance_score', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .map((row) => _memoryFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<List<ArcMemory>> findForControl(
    String userId, {
    int limit = 100,
  }) async {
    final rows = await client
        .from('arc_memories')
        .select(
          'id,user_id,quest_id,mission_id,task_id,trail_id,memory_type,title,content,importance_score,emotional_tone,source_type,source_id,metadata,provenance,sensitivity_level,user_visible,retention_until,created_at,updated_at',
        )
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
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

  @override
  Future<void> update(ArcMemory memory) async {
    await client
        .from('arc_memories')
        .update({
          'title': memory.title,
          'content': memory.content,
          'sensitivity_level': memory.sensitivityLevel.storageKey,
          'user_visible': memory.userVisible,
          'updated_at': memory.updatedAt.toUtc().toIso8601String(),
        })
        .eq('id', memory.id)
        .eq('user_id', memory.userId);
  }

  @override
  Future<void> deleteById(String userId, String memoryId) async {
    await client
        .from('arc_memories')
        .delete()
        .eq('id', memoryId)
        .eq('user_id', userId);
  }

  @override
  Future<void> deleteAllForUser(String userId) async {
    await client.from('arc_memories').delete().eq('user_id', userId);
  }

  @override
  Future<void> deleteByTaskId(String userId, String taskId) async {
    await client
        .from('arc_memories')
        .delete()
        .eq('user_id', userId)
        .eq('task_id', taskId);
  }

  Map<String, Object?> _memoryToRow(ArcMemory memory) {
    return {
      'id': memory.id,
      'user_id': memory.userId,
      'quest_id': memory.questId,
      'mission_id': memory.missionId,
      'task_id': memory.taskId,
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
      'provenance': memory.provenance,
      'sensitivity_level': memory.sensitivityLevel.storageKey,
      'user_visible': memory.userVisible,
      'retention_until': memory.retentionUntil?.toUtc().toIso8601String(),
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
      taskId: row['task_id'] as String?,
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
      provenance: Map<String, Object?>.from(row['provenance'] as Map? ?? {}),
      sensitivityLevel: _sensitivityFromStorage(
        row['sensitivity_level'] as String,
      ),
      userVisible: row['user_visible'] as bool? ?? true,
      retentionUntil: DateTime.tryParse(
        row['retention_until'] as String? ?? '',
      ),
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
