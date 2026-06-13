import 'package:uuid/uuid.dart';

import '../quest/quest_guide_model.dart';

const _uuid = Uuid();

enum MissionDifficulty { easy, normal }

enum MissionStatus { todo, completed }

class Mission {
  Mission({
    String? id,
    required this.questId,
    required this.questTitle,
    required this.title,
    required this.description,
    required this.guideType,
    required this.difficulty,
    required this.status,
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String questId;
  final String questTitle;
  final String title;
  final String description;
  final GuideType guideType;
  final MissionDifficulty difficulty;
  final MissionStatus status;
  final DateTime createdAt;

  Mission copyWith({MissionStatus? status}) {
    return Mission(
      id: id,
      questId: questId,
      questTitle: questTitle,
      title: title,
      description: description,
      guideType: guideType,
      difficulty: difficulty,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
