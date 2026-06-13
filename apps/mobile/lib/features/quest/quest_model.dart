import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum QuestDifficulty { easy, normal, hard, legendary }

enum QuestStatus { draft, active, completed, archived }

enum QuestVisibility { private, guild, public }

class Quest {
  Quest({
    String? id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.status,
    required this.visibility,
    this.targetDate,
  }) : id = id ?? _uuid.v4();

  final String id;
  final String title;
  final String description;
  final QuestDifficulty difficulty;
  final QuestStatus status;
  final QuestVisibility visibility;
  final DateTime? targetDate;

  Quest copyWith({
    String? title,
    String? description,
    QuestDifficulty? difficulty,
    QuestStatus? status,
    QuestVisibility? visibility,
    DateTime? targetDate,
    bool clearTargetDate = false,
  }) {
    return Quest(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      targetDate: clearTargetDate ? null : targetDate ?? this.targetDate,
    );
  }
}

extension QuestEnumLabel on Enum {
  String get label => name[0].toUpperCase() + name.substring(1);
}
