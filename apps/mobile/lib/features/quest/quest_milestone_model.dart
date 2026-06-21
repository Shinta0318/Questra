import 'package:uuid/uuid.dart';

import 'quest_guide_model.dart';

const _uuid = Uuid();

enum QuestMilestoneStatus { planned, active, completed }

class QuestMilestone {
  QuestMilestone({
    String? id,
    required this.questId,
    required this.title,
    required this.description,
    required this.status,
    required this.progress,
    required this.sortOrder,
    this.guideType,
  }) : id = id ?? _uuid.v4();

  final String id;
  final String questId;
  final String title;
  final String description;
  final QuestMilestoneStatus status;
  final double progress;
  final int sortOrder;
  final GuideType? guideType;

  QuestMilestone copyWith({
    String? title,
    String? description,
    QuestMilestoneStatus? status,
    double? progress,
    int? sortOrder,
    GuideType? guideType,
    bool clearGuideType = false,
  }) {
    return QuestMilestone(
      id: id,
      questId: questId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      sortOrder: sortOrder ?? this.sortOrder,
      guideType: clearGuideType ? null : guideType ?? this.guideType,
    );
  }
}

extension QuestMilestoneStatusStorage on QuestMilestoneStatus {
  String get storageKey => name;
}

extension QuestMilestoneStatusLabel on QuestMilestoneStatus {
  String get label {
    return switch (this) {
      QuestMilestoneStatus.planned => '予定',
      QuestMilestoneStatus.active => '進行中',
      QuestMilestoneStatus.completed => '完了',
    };
  }
}

QuestMilestoneStatus questMilestoneStatusFromStorage(String value) {
  return QuestMilestoneStatus.values.firstWhere(
    (status) => status.storageKey == value,
    orElse: () => QuestMilestoneStatus.planned,
  );
}
