import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum TrailEventType {
  questCreated,
  guideGenerated,
  missionCreated,
  missionCompleted,
  arcReflection,
  manualNote,
}

class TrailEvent {
  TrailEvent({
    String? id,
    required this.trailId,
    this.questId,
    this.missionId,
    required this.eventType,
    required this.content,
    this.metadata = const {},
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String trailId;
  final String? questId;
  final String? missionId;
  final TrailEventType eventType;
  final String content;
  final Map<String, Object?> metadata;
  final DateTime createdAt;
}

extension TrailEventTypeStorage on TrailEventType {
  String get storageKey {
    return switch (this) {
      TrailEventType.questCreated => 'quest_created',
      TrailEventType.guideGenerated => 'guide_generated',
      TrailEventType.missionCreated => 'mission_created',
      TrailEventType.missionCompleted => 'mission_completed',
      TrailEventType.arcReflection => 'arc_reflection',
      TrailEventType.manualNote => 'manual_note',
    };
  }
}

TrailEventType trailEventTypeFromStorage(String value) {
  return TrailEventType.values.firstWhere(
    (type) => type.storageKey == value,
    orElse: () => TrailEventType.manualNote,
  );
}
