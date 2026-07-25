import 'package:uuid/uuid.dart';

import '../../core/estimation/effort_estimate.dart';
import '../quest/arc_quest_guide_service.dart';
import '../quest/quest_guide_model.dart';
import 'mission_contract_service.dart';
import 'mission_model.dart';

const _uuid = Uuid();

class MissionCandidateDraft {
  MissionCandidateDraft({
    String? id,
    required this.title,
    required this.description,
    required this.guideType,
    required this.difficulty,
    this.isToday = false,
    this.effortEstimate,
    String? planKey,
    this.purpose = '',
    this.parentPlanKey,
    this.dependencyPlanKeys = const [],
    this.priority = MissionPriority.normal,
    this.category = '実行',
    this.estimatedCostLabel,
    this.referenceHints = const [],
    this.enterpriseSupportHints = const [],
    this.difficultyScore,
    this.estimatedDurationDays,
  }) : id = id ?? _uuid.v4(),
       planKey = planKey ?? id ?? _uuid.v4();

  factory MissionCandidateDraft.fromArcCandidate(
    ArcMissionCandidate candidate,
  ) {
    return MissionCandidateDraft(
      title: candidate.title,
      description: candidate.description,
      guideType: candidate.guideType,
      difficulty: candidate.difficulty,
      effortEstimate: candidate.effortEstimate,
      planKey: candidate.planKey,
      purpose: candidate.purpose,
      parentPlanKey: candidate.parentPlanKey,
      dependencyPlanKeys: candidate.dependencyPlanKeys,
      priority: candidate.priority,
      category: candidate.category,
      estimatedCostLabel: candidate.estimatedCostLabel,
      referenceHints: candidate.referenceHints,
      enterpriseSupportHints: candidate.enterpriseSupportHints,
      difficultyScore: candidate.difficultyScore,
      estimatedDurationDays: candidate.estimatedDurationDays,
    );
  }

  final String id;
  final String title;
  final String description;
  final GuideType guideType;
  final MissionDifficulty difficulty;
  final bool isToday;
  final EffortEstimate? effortEstimate;
  final String planKey;
  final String purpose;
  final String? parentPlanKey;
  final List<String> dependencyPlanKeys;
  final MissionPriority priority;
  final String category;
  final String? estimatedCostLabel;
  final List<String> referenceHints;
  final List<String> enterpriseSupportHints;
  final int? difficultyScore;
  final int? estimatedDurationDays;

  MissionCandidateDraft copyWith({
    String? planKey,
    String? title,
    String? description,
    GuideType? guideType,
    MissionDifficulty? difficulty,
    bool? isToday,
    EffortEstimate? effortEstimate,
    String? purpose,
    String? parentPlanKey,
    bool clearParentPlan = false,
    List<String>? dependencyPlanKeys,
    MissionPriority? priority,
    String? category,
    String? estimatedCostLabel,
    List<String>? referenceHints,
    List<String>? enterpriseSupportHints,
    int? difficultyScore,
    int? estimatedDurationDays,
  }) {
    return MissionCandidateDraft(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      guideType: guideType ?? this.guideType,
      difficulty: difficulty ?? this.difficulty,
      isToday: isToday ?? this.isToday,
      effortEstimate: effortEstimate ?? this.effortEstimate,
      planKey: planKey ?? this.planKey,
      purpose: purpose ?? this.purpose,
      parentPlanKey: clearParentPlan
          ? null
          : parentPlanKey ?? this.parentPlanKey,
      dependencyPlanKeys: dependencyPlanKeys ?? this.dependencyPlanKeys,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      estimatedCostLabel: estimatedCostLabel ?? this.estimatedCostLabel,
      referenceHints: referenceHints ?? this.referenceHints,
      enterpriseSupportHints:
          enterpriseSupportHints ?? this.enterpriseSupportHints,
      difficultyScore: difficultyScore ?? this.difficultyScore,
      estimatedDurationDays:
          estimatedDurationDays ?? this.estimatedDurationDays,
    );
  }
}

class MissionPlanDraft {
  const MissionPlanDraft({required this.candidates});

  factory MissionPlanDraft.fromArcGuide(
    ArcQuestGuide guide, {
    required String questTitle,
  }) {
    const contract = MissionContractService();
    final usedTitles = <String>{};
    final candidates = <MissionCandidateDraft>[];
    for (final candidate in guide.missionCandidates.take(30)) {
      final title = contract.distinctGeneratedTitle(
        questTitle: questTitle,
        missionTitle: candidate.title,
        usedTitles: usedTitles,
      );
      if (title == null) continue;
      candidates.add(
        MissionCandidateDraft.fromArcCandidate(
          candidate,
        ).copyWith(title: title),
      );
    }
    return MissionPlanDraft(candidates: candidates);
  }

  final List<MissionCandidateDraft> candidates;

  MissionPlanDraft update(MissionCandidateDraft updated) {
    return MissionPlanDraft(
      candidates: [
        for (final candidate in candidates)
          if (candidate.id == updated.id) updated else candidate,
      ],
    );
  }

  MissionPlanDraft add() {
    if (candidates.length >= 30) return this;
    return MissionPlanDraft(
      candidates: [
        ...candidates,
        MissionCandidateDraft(
          title: '新しいMission',
          description: '今日できる小さな一歩に整えます。',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
      ],
    );
  }

  MissionPlanDraft remove(String id) {
    if (candidates.length <= 1) return this;
    return MissionPlanDraft(
      candidates: candidates.where((candidate) => candidate.id != id).toList(),
    );
  }

  MissionPlanDraft move(int from, int to) {
    if (from == to || from < 0 || from >= candidates.length) return this;
    if (to < 0 || to >= candidates.length) return this;
    final reordered = [...candidates];
    final candidate = reordered.removeAt(from);
    reordered.insert(to, candidate);
    return MissionPlanDraft(candidates: reordered);
  }

  MissionPlanDraft markToday(String id) {
    return MissionPlanDraft(
      candidates: [
        for (final candidate in candidates)
          candidate.copyWith(isToday: candidate.id == id),
      ],
    );
  }

  List<MissionCandidateDraft> get validCandidates => candidates
      .where((candidate) => candidate.title.trim().isNotEmpty)
      .take(30)
      .toList(growable: false);
}
