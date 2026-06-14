import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum TrailType { questRecord, missionRecord, arcReflection, manualNote }

class Trail {
  Trail({
    String? id,
    required this.questId,
    this.missionId,
    required this.title,
    required this.summary,
    required this.content,
    required this.trailType,
    this.sourceType = 'trail',
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String questId;
  final String? missionId;
  final String title;
  final String summary;
  final String content;
  final TrailType trailType;
  final String sourceType;
  final DateTime createdAt;
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
}
