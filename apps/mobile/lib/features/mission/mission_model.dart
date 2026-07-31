import 'package:uuid/uuid.dart';

import '../../core/estimation/effort_estimate.dart';
import '../quest/quest_guide_model.dart';

const _uuid = Uuid();

enum MissionDifficulty { easy, normal }

enum MissionStatus { todo, completed }

enum MissionRouteState { active, paused, removed }

enum MissionPriority { low, normal, high, critical }

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
    int? progressPercent,
    this.sortOrder = 0,
    this.isToday = false,
    DateTime? createdAt,
    this.effortEstimate,
    this.parentMissionId,
    this.dependencyIds = const [],
    this.priority = MissionPriority.normal,
    this.category = '実行',
    this.estimatedCostLabel,
    this.referenceHints = const [],
    this.enterpriseSupportHints = const [],
    this.difficultyScore,
    this.estimatedDurationDays,
    this.routeState = MissionRouteState.active,
    this.doneCondition = '',
    this.expectedOutput = '',
    this.verificationType = 'self_check',
  }) : id = id ?? _uuid.v4(),
       progressPercent =
           progressPercent ?? (status == MissionStatus.completed ? 100 : 0),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String questId;
  final String questTitle;
  final String title;
  final String description;
  final GuideType guideType;
  final MissionDifficulty difficulty;
  final MissionStatus status;
  final int progressPercent;
  final int sortOrder;
  final bool isToday;
  final DateTime createdAt;
  final EffortEstimate? effortEstimate;
  final String? parentMissionId;
  final List<String> dependencyIds;
  final MissionPriority priority;
  final String category;
  final String? estimatedCostLabel;
  final List<String> referenceHints;
  final List<String> enterpriseSupportHints;
  final int? difficultyScore;
  final int? estimatedDurationDays;
  final MissionRouteState routeState;
  final String doneCondition;
  final String expectedOutput;
  final String verificationType;

  Mission copyWith({
    String? title,
    String? description,
    GuideType? guideType,
    MissionDifficulty? difficulty,
    MissionStatus? status,
    int? progressPercent,
    int? sortOrder,
    bool? isToday,
    EffortEstimate? effortEstimate,
    String? parentMissionId,
    bool clearParentMission = false,
    List<String>? dependencyIds,
    MissionPriority? priority,
    String? category,
    String? estimatedCostLabel,
    List<String>? referenceHints,
    List<String>? enterpriseSupportHints,
    int? difficultyScore,
    int? estimatedDurationDays,
    MissionRouteState? routeState,
    String? doneCondition,
    String? expectedOutput,
    String? verificationType,
  }) {
    return Mission(
      id: id,
      questId: questId,
      questTitle: questTitle,
      title: title ?? this.title,
      description: description ?? this.description,
      guideType: guideType ?? this.guideType,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      sortOrder: sortOrder ?? this.sortOrder,
      isToday: isToday ?? this.isToday,
      createdAt: createdAt,
      effortEstimate: effortEstimate ?? this.effortEstimate,
      parentMissionId: clearParentMission
          ? null
          : parentMissionId ?? this.parentMissionId,
      dependencyIds: dependencyIds ?? this.dependencyIds,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      estimatedCostLabel: estimatedCostLabel ?? this.estimatedCostLabel,
      referenceHints: referenceHints ?? this.referenceHints,
      enterpriseSupportHints:
          enterpriseSupportHints ?? this.enterpriseSupportHints,
      difficultyScore: difficultyScore ?? this.difficultyScore,
      estimatedDurationDays:
          estimatedDurationDays ?? this.estimatedDurationDays,
      routeState: routeState ?? this.routeState,
      doneCondition: doneCondition ?? this.doneCondition,
      expectedOutput: expectedOutput ?? this.expectedOutput,
      verificationType: verificationType ?? this.verificationType,
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

extension MissionPriorityStorage on MissionPriority {
  String get storageKey => name;

  String get label => switch (this) {
    MissionPriority.low => '低',
    MissionPriority.normal => '標準',
    MissionPriority.high => '高',
    MissionPriority.critical => '最優先',
  };
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

MissionPriority missionPriorityFromStorage(String value) {
  return MissionPriority.values.firstWhere(
    (priority) => priority.storageKey == value,
    orElse: () => MissionPriority.normal,
  );
}

MissionRouteState missionRouteStateFromStorage(String value) {
  return MissionRouteState.values.firstWhere(
    (state) => state.name == value,
    orElse: () => MissionRouteState.active,
  );
}

GuideType guideTypeFromStorage(String value) {
  return GuideType.values.firstWhere(
    (guideType) => guideType.storageKey == value,
    orElse: () => GuideType.route,
  );
}
