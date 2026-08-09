import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum TrailType { questRecord, missionRecord, arcReflection, manualNote }

class Trail {
  Trail({
    String? id,
    this.questId,
    this.missionId,
    this.taskId,
    required this.title,
    required this.summary,
    required this.content,
    required this.trailType,
    this.sourceType = 'trail',
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String? questId;
  final String? missionId;
  final String? taskId;
  final String title;
  final String summary;
  final String content;
  final TrailType trailType;
  final String sourceType;
  final DateTime createdAt;

  static String createId() => _uuid.v4();

  Trail copyWith({
    String? questId,
    String? missionId,
    String? taskId,
    String? title,
    String? summary,
    String? content,
    TrailType? trailType,
    String? sourceType,
    DateTime? createdAt,
  }) {
    return Trail(
      id: id,
      questId: questId ?? this.questId,
      missionId: missionId ?? this.missionId,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      trailType: trailType ?? this.trailType,
      sourceType: sourceType ?? this.sourceType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TrailParentContext {
  const TrailParentContext({
    required this.questId,
    required this.questTitle,
    this.missionId,
    this.missionTitle,
    this.taskId,
    this.taskTitle,
  });

  final String questId;
  final String questTitle;
  final String? missionId;
  final String? missionTitle;
  final String? taskId;
  final String? taskTitle;

  bool get isStructurallyValid {
    if (questId.trim().isEmpty || questTitle.trim().isEmpty) return false;
    if (missionId == null) return taskId == null;
    if (missionId!.trim().isEmpty || (missionTitle?.trim().isEmpty ?? true)) {
      return false;
    }
    if (taskId == null) return true;
    return taskId!.trim().isNotEmpty && (taskTitle?.trim().isNotEmpty ?? false);
  }

  String get compactLabel {
    if (taskTitle case final title?) return 'Task: $title';
    if (missionTitle case final title?) return 'Mission: $title';
    return 'Quest: $questTitle';
  }
}

extension TrailTypeLabel on TrailType {
  String get label {
    return switch (this) {
      TrailType.questRecord => 'Quest記録',
      TrailType.missionRecord => 'Mission記録',
      TrailType.arcReflection => 'Arcリフレクション',
      TrailType.manualNote => '手動メモ',
    };
  }

  String get storageKey {
    return switch (this) {
      TrailType.questRecord => 'quest_record',
      TrailType.missionRecord => 'mission_record',
      TrailType.arcReflection => 'arc_reflection',
      TrailType.manualNote => 'manual_note',
    };
  }
}

TrailType trailTypeFromStorage(String value) {
  return TrailType.values.firstWhere(
    (type) => type.storageKey == value,
    orElse: () => TrailType.questRecord,
  );
}
