import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum TaskStatus {
  pending,
  ready,
  inProgress,
  completed,
  skipped,
  blocked,
  cancelled,
}

enum TaskVerificationType { self, evidence, arcReview, external }

enum TaskGeneratedBy { user, arc, system, migration }

class QuestraTask {
  QuestraTask({
    String? id,
    required this.questId,
    required this.missionId,
    required this.title,
    required this.action,
    required this.doneCondition,
    this.questTitle = '',
    this.missionTitle = '',
    this.purpose = '',
    this.expectedOutput = '',
    this.estimatedEffortMinutes,
    this.status = TaskStatus.pending,
    this.required = true,
    this.orderIndex = 0,
    this.dependencyIds = const [],
    this.scheduledDate,
    this.dueDate,
    this.completedAt,
    this.verificationType = TaskVerificationType.self,
    this.generatedBy = TaskGeneratedBy.user,
    this.generationVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  final String questId;
  final String missionId;
  final String questTitle;
  final String missionTitle;
  final String title;
  final String action;
  final String purpose;
  final String doneCondition;
  final String expectedOutput;
  final int? estimatedEffortMinutes;
  final TaskStatus status;
  final bool required;
  final int orderIndex;
  final List<String> dependencyIds;
  final DateTime? scheduledDate;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final TaskVerificationType verificationType;
  final TaskGeneratedBy generatedBy;
  final String? generationVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => !{
    TaskStatus.completed,
    TaskStatus.skipped,
    TaskStatus.cancelled,
  }.contains(status);

  QuestraTask copyWith({
    String? title,
    String? action,
    String? purpose,
    String? doneCondition,
    String? expectedOutput,
    int? estimatedEffortMinutes,
    TaskStatus? status,
    bool? required,
    int? orderIndex,
    List<String>? dependencyIds,
    DateTime? scheduledDate,
    bool clearScheduledDate = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    TaskVerificationType? verificationType,
  }) => QuestraTask(
    id: id,
    questId: questId,
    missionId: missionId,
    questTitle: questTitle,
    missionTitle: missionTitle,
    title: title ?? this.title,
    action: action ?? this.action,
    purpose: purpose ?? this.purpose,
    doneCondition: doneCondition ?? this.doneCondition,
    expectedOutput: expectedOutput ?? this.expectedOutput,
    estimatedEffortMinutes:
        estimatedEffortMinutes ?? this.estimatedEffortMinutes,
    status: status ?? this.status,
    required: required ?? this.required,
    orderIndex: orderIndex ?? this.orderIndex,
    dependencyIds: dependencyIds ?? this.dependencyIds,
    scheduledDate: clearScheduledDate
        ? null
        : scheduledDate ?? this.scheduledDate,
    dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    verificationType: verificationType ?? this.verificationType,
    generatedBy: generatedBy,
    generationVersion: generationVersion,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

extension TaskStatusStorage on TaskStatus {
  String get storageKey => switch (this) {
    TaskStatus.inProgress => 'in_progress',
    _ => name,
  };

  String get label => switch (this) {
    TaskStatus.pending => '準備中',
    TaskStatus.ready => '開始できます',
    TaskStatus.inProgress => '進行中',
    TaskStatus.completed => '完了',
    TaskStatus.skipped => '見送り',
    TaskStatus.blocked => '保留',
    TaskStatus.cancelled => '中止',
  };
}

extension TaskVerificationTypeStorage on TaskVerificationType {
  String get storageKey => switch (this) {
    TaskVerificationType.arcReview => 'arc_review',
    _ => name,
  };
}

TaskVerificationType taskVerificationTypeFromStorage(String value) =>
    TaskVerificationType.values.firstWhere(
      (type) => type.storageKey == value,
      orElse: () => TaskVerificationType.self,
    );

TaskStatus taskStatusFromStorage(String value) => TaskStatus.values.firstWhere(
  (status) => status.storageKey == value,
  orElse: () => TaskStatus.pending,
);

T enumFromStorage<T extends Enum>(List<T> values, String value, T fallback) =>
    values.firstWhere((item) => item.name == value, orElse: () => fallback);
