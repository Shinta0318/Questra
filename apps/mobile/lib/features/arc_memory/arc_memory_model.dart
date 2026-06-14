import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum ArcMemoryType {
  questMemory,
  missionMemory,
  trailMemory,
  preferenceMemory,
  emotionalMemory,
  lifeEventMemory,
  arcRelationshipMemory,
}

enum ArcMemorySourceType {
  questCreated,
  questUpdated,
  missionCreated,
  missionCompleted,
  trailPosted,
  arcChat,
  guildPost,
}

enum EmotionalTone {
  neutral,
  positive,
  excited,
  supportive,
  serious,
  worried,
  lonely,
  celebratory,
}

enum SensitivityLevel { standard, personal, sensitive }

class ArcMemory {
  ArcMemory({
    String? id,
    required this.userId,
    this.questId,
    this.missionId,
    this.trailId,
    required this.memoryType,
    required this.title,
    required this.content,
    required this.importanceScore,
    required this.emotionalTone,
    required this.sourceType,
    this.sourceId,
    this.embedding,
    this.metadata = const {},
    this.sensitivityLevel = SensitivityLevel.standard,
    this.userVisible = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String userId;
  final String? questId;
  final String? missionId;
  final String? trailId;
  final ArcMemoryType memoryType;
  final String title;
  final String content;
  final double importanceScore;
  final EmotionalTone emotionalTone;
  final ArcMemorySourceType sourceType;
  final String? sourceId;
  final List<double>? embedding;
  final Map<String, Object?> metadata;
  final SensitivityLevel sensitivityLevel;
  final bool userVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get dedupeKey {
    final normalized = content
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
    return '${userId}_${memoryType.name}_${sourceId ?? sourceType.name}_$normalized';
  }
}

class MemoryExtractionEvent {
  const MemoryExtractionEvent({
    required this.userId,
    required this.sourceType,
    required this.text,
    this.sourceId,
    this.questId,
    this.missionId,
    this.trailId,
    this.title,
    this.metadata = const {},
  });

  final String userId;
  final ArcMemorySourceType sourceType;
  final String text;
  final String? sourceId;
  final String? questId;
  final String? missionId;
  final String? trailId;
  final String? title;
  final Map<String, Object?> metadata;
}

extension ArcMemoryTypeStorageKey on ArcMemoryType {
  String get storageKey {
    return switch (this) {
      ArcMemoryType.questMemory => 'quest_memory',
      ArcMemoryType.missionMemory => 'mission_memory',
      ArcMemoryType.trailMemory => 'trail_memory',
      ArcMemoryType.preferenceMemory => 'preference_memory',
      ArcMemoryType.emotionalMemory => 'emotional_memory',
      ArcMemoryType.lifeEventMemory => 'life_event_memory',
      ArcMemoryType.arcRelationshipMemory => 'arc_relationship_memory',
    };
  }
}

extension ArcMemorySourceStorageKey on ArcMemorySourceType {
  String get storageKey {
    return switch (this) {
      ArcMemorySourceType.questCreated => 'quest_created',
      ArcMemorySourceType.questUpdated => 'quest_updated',
      ArcMemorySourceType.missionCreated => 'mission_created',
      ArcMemorySourceType.missionCompleted => 'mission_completed',
      ArcMemorySourceType.trailPosted => 'trail_posted',
      ArcMemorySourceType.arcChat => 'arc_chat',
      ArcMemorySourceType.guildPost => 'guild_post',
    };
  }
}

extension EmotionalToneStorageKey on EmotionalTone {
  String get storageKey {
    return switch (this) {
      EmotionalTone.neutral => 'neutral',
      EmotionalTone.positive => 'positive',
      EmotionalTone.excited => 'excited',
      EmotionalTone.supportive => 'supportive',
      EmotionalTone.serious => 'serious',
      EmotionalTone.worried => 'worried',
      EmotionalTone.lonely => 'lonely',
      EmotionalTone.celebratory => 'celebratory',
    };
  }
}

extension SensitivityLevelStorageKey on SensitivityLevel {
  String get storageKey {
    return switch (this) {
      SensitivityLevel.standard => 'standard',
      SensitivityLevel.personal => 'personal',
      SensitivityLevel.sensitive => 'sensitive',
    };
  }
}
