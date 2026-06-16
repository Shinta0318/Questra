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

extension MissionDifficultyStorage on MissionDifficulty {
  String get storageKey => name;
}

extension MissionStatusStorage on MissionStatus {
  String get storageKey {
    return switch (this) {
      MissionStatus.todo => 'todo',
      MissionStatus.completed => 'completed',
    };
  }
}

extension GuideTypeStorage on GuideType {
  String get storageKey => name;
}

MissionDifficulty missionDifficultyFromStorage(String value) {
  return MissionDifficulty.values.firstWhere(
    (difficulty) => difficulty.storageKey == value,
    orElse: () => MissionDifficulty.easy,
  );
}

MissionStatus missionStatusFromStorage(String value) {
  return MissionStatus.values.firstWhere(
    (status) => status.storageKey == value,
    orElse: () => MissionStatus.todo,
  );
}

GuideType guideTypeFromStorage(String value) {
  return GuideType.values.firstWhere(
    (guideType) => guideType.storageKey == value,
    orElse: () => GuideType.route,
  );
}
