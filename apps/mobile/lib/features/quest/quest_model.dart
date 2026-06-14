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
    this.progress = 0,
    this.category = '冒険',
    this.targetDate,
  }) : id = id ?? _uuid.v4();

  final String id;
  final String title;
  final String description;
  final QuestDifficulty difficulty;
  final QuestStatus status;
  final QuestVisibility visibility;
  final double progress;
  final String category;
  final DateTime? targetDate;

  Quest copyWith({
    String? title,
    String? description,
    QuestDifficulty? difficulty,
    QuestStatus? status,
    QuestVisibility? visibility,
    double? progress,
    String? category,
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
      progress: progress ?? this.progress,
      category: category ?? this.category,
      targetDate: clearTargetDate ? null : targetDate ?? this.targetDate,
    );
  }
}

extension QuestEnumLabel on Enum {
  String get label {
    return switch (this) {
      QuestDifficulty.easy => 'やさしい',
      QuestDifficulty.normal => 'ふつう',
      QuestDifficulty.hard => 'むずかしい',
      QuestDifficulty.legendary => '伝説級',
      QuestStatus.draft => '準備中',
      QuestStatus.active => '進行中',
      QuestStatus.completed => '完了',
      QuestStatus.archived => '保管',
      QuestVisibility.private => '自分だけ',
      QuestVisibility.guild => 'ギルド',
      QuestVisibility.public => '公開',
      _ => name[0].toUpperCase() + name.substring(1),
    };
  }
}
