import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum TagEntityType { quest, mission, trail, arcMemory }

class Tag {
  Tag({
    String? id,
    required this.ownerId,
    required this.name,
    required this.normalizedName,
    this.sourceType = 'ai',
    this.usageCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String ownerId;
  final String name;
  final String normalizedName;
  final String sourceType;
  final int usageCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class EntityTag {
  EntityTag({
    String? id,
    required this.ownerId,
    required this.tagId,
    required this.entityType,
    required this.entityId,
    this.confidence = 0.72,
    this.sourceType = 'ai',
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String ownerId;
  final String tagId;
  final TagEntityType entityType;
  final String entityId;
  final double confidence;
  final String sourceType;
  final DateTime createdAt;
}

class EntityTagsResult {
  const EntityTagsResult({
    required this.entityType,
    required this.entityId,
    required this.tags,
  });

  final TagEntityType entityType;
  final String entityId;
  final List<Tag> tags;
}

class TagStat {
  const TagStat({required this.tag, required this.count});

  final Tag tag;
  final int count;
}

extension TagEntityTypeStorage on TagEntityType {
  String get storageKey {
    return switch (this) {
      TagEntityType.quest => 'quest',
      TagEntityType.mission => 'mission',
      TagEntityType.trail => 'trail',
      TagEntityType.arcMemory => 'arc_memory',
    };
  }
}

TagEntityType tagEntityTypeFromStorage(String value) {
  return TagEntityType.values.firstWhere(
    (type) => type.storageKey == value,
    orElse: () => TagEntityType.quest,
  );
}
