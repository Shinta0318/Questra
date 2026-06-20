import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'ai_tag_service.dart';
import 'tag_model.dart';

abstract interface class TagRepository {
  Future<EntityTagsResult> saveEntityTags({
    required TaggingInput input,
    required List<GeneratedTag> tags,
  });

  Future<List<Tag>> findByEntity({
    required String ownerId,
    required TagEntityType entityType,
    required String entityId,
  });

  Future<List<EntityTagsResult>> searchByTag({
    required String ownerId,
    required String query,
    int limit = 30,
  });

  Future<List<TagStat>> stats({required String ownerId, int limit = 20});
}

class InMemoryTagRepository implements TagRepository {
  final _tags = <Tag>[];
  final _entityTags = <EntityTag>[];

  @override
  Future<EntityTagsResult> saveEntityTags({
    required TaggingInput input,
    required List<GeneratedTag> tags,
  }) async {
    final savedTags = <Tag>[];
    for (final generated in tags) {
      final normalized = normalizeTagName(generated.name);
      if (normalized.isEmpty) {
        continue;
      }
      final tag = _upsertTag(
        ownerId: input.ownerId,
        name: generated.name,
        normalizedName: normalized,
      );
      _entityTags.removeWhere(
        (entityTag) =>
            entityTag.ownerId == input.ownerId &&
            entityTag.entityType == input.entityType &&
            entityTag.entityId == input.entityId &&
            entityTag.tagId == tag.id,
      );
      _entityTags.add(
        EntityTag(
          ownerId: input.ownerId,
          tagId: tag.id,
          entityType: input.entityType,
          entityId: input.entityId,
          confidence: generated.confidence,
        ),
      );
      savedTags.add(tag);
    }
    return EntityTagsResult(
      entityType: input.entityType,
      entityId: input.entityId,
      tags: savedTags,
    );
  }

  @override
  Future<List<Tag>> findByEntity({
    required String ownerId,
    required TagEntityType entityType,
    required String entityId,
  }) async {
    final tagIds = _entityTags
        .where(
          (entityTag) =>
              entityTag.ownerId == ownerId &&
              entityTag.entityType == entityType &&
              entityTag.entityId == entityId,
        )
        .map((entityTag) => entityTag.tagId)
        .toSet();
    return _tags.where((tag) => tagIds.contains(tag.id)).toList();
  }

  @override
  Future<List<EntityTagsResult>> searchByTag({
    required String ownerId,
    required String query,
    int limit = 30,
  }) async {
    final normalized = normalizeTagName(query);
    final matchedTagIds = _tags
        .where(
          (tag) =>
              tag.ownerId == ownerId && tag.normalizedName.contains(normalized),
        )
        .map((tag) => tag.id)
        .toSet();
    final grouped = <String, List<Tag>>{};
    final entityTypes = <String, TagEntityType>{};
    for (final entityTag in _entityTags.where(
      (entityTag) =>
          entityTag.ownerId == ownerId &&
          matchedTagIds.contains(entityTag.tagId),
    )) {
      final key = '${entityTag.entityType.storageKey}:${entityTag.entityId}';
      entityTypes[key] = entityTag.entityType;
      grouped
          .putIfAbsent(key, () => [])
          .add(_tags.firstWhere((tag) => tag.id == entityTag.tagId));
    }
    return grouped.entries
        .take(limit)
        .map(
          (entry) => EntityTagsResult(
            entityType: entityTypes[entry.key] ?? TagEntityType.quest,
            entityId: entry.key.split(':').last,
            tags: entry.value,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<TagStat>> stats({required String ownerId, int limit = 20}) async {
    final counts = <String, int>{};
    for (final entityTag in _entityTags.where(
      (tag) => tag.ownerId == ownerId,
    )) {
      counts[entityTag.tagId] = (counts[entityTag.tagId] ?? 0) + 1;
    }
    final stats =
        counts.entries
            .map(
              (entry) => TagStat(
                tag: _tags.firstWhere((tag) => tag.id == entry.key),
                count: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    return stats.take(limit).toList(growable: false);
  }

  Tag _upsertTag({
    required String ownerId,
    required String name,
    required String normalizedName,
  }) {
    for (final tag in _tags) {
      if (tag.ownerId == ownerId && tag.normalizedName == normalizedName) {
        final updated = Tag(
          id: tag.id,
          ownerId: tag.ownerId,
          name: tag.name,
          normalizedName: tag.normalizedName,
          sourceType: tag.sourceType,
          usageCount: tag.usageCount + 1,
          createdAt: tag.createdAt,
        );
        _tags
          ..removeWhere((current) => current.id == tag.id)
          ..add(updated);
        return updated;
      }
    }
    final tag = Tag(
      ownerId: ownerId,
      name: _displayName(name),
      normalizedName: normalizedName,
      usageCount: 1,
    );
    _tags.add(tag);
    return tag;
  }
}

class SupabaseTagRepository implements TagRepository {
  const SupabaseTagRepository(this.client);

  final SupabaseClient client;

  @override
  Future<EntityTagsResult> saveEntityTags({
    required TaggingInput input,
    required List<GeneratedTag> tags,
  }) async {
    final savedTags = <Tag>[];
    for (final generated in tags) {
      final normalized = normalizeTagName(generated.name);
      if (normalized.isEmpty) {
        continue;
      }
      final tag = await _upsertTag(
        ownerId: input.ownerId,
        name: generated.name,
        normalizedName: normalized,
      );
      await client.from('entity_tags').upsert({
        'owner_id': input.ownerId,
        'tag_id': tag.id,
        'entity_type': input.entityType.storageKey,
        'entity_id': input.entityId,
        'confidence': generated.confidence,
        'source_type': 'ai',
      }, onConflict: 'owner_id,entity_type,entity_id,tag_id');
      savedTags.add(tag);
    }
    return EntityTagsResult(
      entityType: input.entityType,
      entityId: input.entityId,
      tags: savedTags,
    );
  }

  @override
  Future<List<Tag>> findByEntity({
    required String ownerId,
    required TagEntityType entityType,
    required String entityId,
  }) async {
    final rows = await client
        .from('entity_tags')
        .select(
          'tags(id,owner_id,name,normalized_name,source_type,usage_count,created_at,updated_at)',
        )
        .eq('owner_id', ownerId)
        .eq('entity_type', entityType.storageKey)
        .eq('entity_id', entityId);
    return rows
        .map(
          (row) => _tagFromRow(Map<String, dynamic>.from(row['tags'] as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<EntityTagsResult>> searchByTag({
    required String ownerId,
    required String query,
    int limit = 30,
  }) async {
    final normalized = normalizeTagName(query);
    final rows = await client
        .from('entity_tags')
        .select(
          'entity_type,entity_id,tags(id,owner_id,name,normalized_name,source_type,usage_count,created_at,updated_at)',
        )
        .eq('owner_id', ownerId)
        .ilike('tags.normalized_name', '%$normalized%')
        .limit(limit);
    return rows
        .map((row) {
          final data = Map<String, dynamic>.from(row);
          return EntityTagsResult(
            entityType: tagEntityTypeFromStorage(data['entity_type'] as String),
            entityId: data['entity_id'] as String,
            tags: [_tagFromRow(Map<String, dynamic>.from(data['tags'] as Map))],
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<TagStat>> stats({required String ownerId, int limit = 20}) async {
    final rows = await client
        .from('tags')
        .select(
          'id,owner_id,name,normalized_name,source_type,usage_count,created_at,updated_at',
        )
        .eq('owner_id', ownerId)
        .order('usage_count', ascending: false)
        .limit(limit);
    return rows
        .map((row) {
          final tag = _tagFromRow(Map<String, dynamic>.from(row));
          return TagStat(tag: tag, count: tag.usageCount);
        })
        .toList(growable: false);
  }

  Future<Tag> _upsertTag({
    required String ownerId,
    required String name,
    required String normalizedName,
  }) async {
    final existingRows = await client
        .from('tags')
        .select(
          'id,owner_id,name,normalized_name,source_type,usage_count,created_at,updated_at',
        )
        .eq('owner_id', ownerId)
        .eq('normalized_name', normalizedName)
        .limit(1);
    if (existingRows.isNotEmpty) {
      final existing = _tagFromRow(
        Map<String, dynamic>.from(existingRows.first),
      );
      final rows = await client
          .from('tags')
          .update({'usage_count': existing.usageCount + 1})
          .eq('id', existing.id)
          .select(
            'id,owner_id,name,normalized_name,source_type,usage_count,created_at,updated_at',
          );
      return _tagFromRow(Map<String, dynamic>.from(rows.first));
    }

    final rows = await client
        .from('tags')
        .insert({
          'owner_id': ownerId,
          'name': _displayName(name),
          'normalized_name': normalizedName,
          'source_type': 'ai',
          'usage_count': 1,
        })
        .select(
          'id,owner_id,name,normalized_name,source_type,usage_count,created_at,updated_at',
        );
    return _tagFromRow(Map<String, dynamic>.from(rows.first));
  }

  Tag _tagFromRow(Map<String, dynamic> row) {
    return Tag(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      name: row['name'] as String,
      normalizedName: row['normalized_name'] as String,
      sourceType: row['source_type'] as String? ?? 'ai',
      usageCount: row['usage_count'] as int? ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}

String normalizeTagName(String name) {
  return name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9一-龠ぁ-んァ-ンー]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String _displayName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'General';
  }
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}
