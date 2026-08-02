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
    this.doneCondition = '',
    this.expectedOutput = '',
    this.verificationType = 'self_check',
    this.action = '',
    this.isOptional = false,
    this.sourceRequirement = 'none',
    this.confidence = 0.5,
    this.parentPlanKey,
    this.dependencyPlanKeys = const [],
    this.priority = MissionPriority.normal,
    this.category = '実行',
    this.estimatedCostLabel,
    this.referenceHints = const [],
    this.enterpriseSupportHints = const [],
    this.difficultyScore,
    this.estimatedDurationDays,
    this.reasonRequired = '',
    this.coveredSuccessConditions = const [],
    this.parallelizable = false,
    this.childTaskEstimate = 2,
    this.criticScores = const {},
    this.criticVerdict = 'pass',
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
      doneCondition: candidate.doneCondition,
      expectedOutput: candidate.expectedOutput,
      verificationType: candidate.verificationType,
      action: candidate.action,
      isOptional: candidate.isOptional,
      sourceRequirement: candidate.sourceRequirement,
      confidence: candidate.confidence,
      parentPlanKey: candidate.parentPlanKey,
      dependencyPlanKeys: candidate.dependencyPlanKeys,
      priority: candidate.priority,
      category: candidate.category,
      estimatedCostLabel: candidate.estimatedCostLabel,
      referenceHints: candidate.referenceHints,
      enterpriseSupportHints: candidate.enterpriseSupportHints,
      difficultyScore: candidate.difficultyScore,
      estimatedDurationDays: candidate.estimatedDurationDays,
      reasonRequired: candidate.reasonRequired,
      coveredSuccessConditions: candidate.coveredSuccessConditions,
      parallelizable: candidate.parallelizable,
      childTaskEstimate: candidate.childTaskEstimate,
      criticScores: candidate.criticScores,
      criticVerdict: candidate.criticVerdict,
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
  final String doneCondition;
  final String expectedOutput;
  final String verificationType;
  final String action;
  final bool isOptional;
  final String sourceRequirement;
  final double confidence;
  final String? parentPlanKey;
  final List<String> dependencyPlanKeys;
  final MissionPriority priority;
  final String category;
  final String? estimatedCostLabel;
  final List<String> referenceHints;
  final List<String> enterpriseSupportHints;
  final int? difficultyScore;
  final int? estimatedDurationDays;
  final String reasonRequired;
  final List<String> coveredSuccessConditions;
  final bool parallelizable;
  final int childTaskEstimate;
  final Map<String, int> criticScores;
  final String criticVerdict;

  MissionCandidateDraft copyWith({
    String? planKey,
    String? title,
    String? description,
    GuideType? guideType,
    MissionDifficulty? difficulty,
    bool? isToday,
    EffortEstimate? effortEstimate,
    String? purpose,
    String? doneCondition,
    String? expectedOutput,
    String? verificationType,
    String? action,
    bool? isOptional,
    String? sourceRequirement,
    double? confidence,
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
    String? reasonRequired,
    List<String>? coveredSuccessConditions,
    bool? parallelizable,
    int? childTaskEstimate,
    Map<String, int>? criticScores,
    String? criticVerdict,
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
      doneCondition: doneCondition ?? this.doneCondition,
      expectedOutput: expectedOutput ?? this.expectedOutput,
      verificationType: verificationType ?? this.verificationType,
      action: action ?? this.action,
      isOptional: isOptional ?? this.isOptional,
      sourceRequirement: sourceRequirement ?? this.sourceRequirement,
      confidence: confidence ?? this.confidence,
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
      reasonRequired: reasonRequired ?? this.reasonRequired,
      coveredSuccessConditions:
          coveredSuccessConditions ?? this.coveredSuccessConditions,
      parallelizable: parallelizable ?? this.parallelizable,
      childTaskEstimate: childTaskEstimate ?? this.childTaskEstimate,
      criticScores: criticScores ?? this.criticScores,
      criticVerdict: criticVerdict ?? this.criticVerdict,
    );
  }

  ArcMissionCandidate toArcCandidate() => ArcMissionCandidate(
    planKey: planKey,
    title: title,
    description: description,
    purpose: purpose,
    doneCondition: doneCondition,
    expectedOutput: expectedOutput,
    verificationType: verificationType,
    action: action,
    isOptional: isOptional,
    sourceRequirement: sourceRequirement,
    confidence: confidence,
    parentPlanKey: parentPlanKey,
    dependencyPlanKeys: dependencyPlanKeys,
    guideType: guideType,
    difficulty: difficulty,
    effortEstimate: effortEstimate,
    priority: priority,
    category: category,
    estimatedCostLabel: estimatedCostLabel,
    referenceHints: referenceHints,
    enterpriseSupportHints: enterpriseSupportHints,
    difficultyScore: difficultyScore,
    estimatedDurationDays: estimatedDurationDays,
    reasonRequired: reasonRequired,
    coveredSuccessConditions: coveredSuccessConditions,
    parallelizable: parallelizable,
    childTaskEstimate: childTaskEstimate,
    criticScores: criticScores,
    criticVerdict: criticVerdict,
  );
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
          description: 'このMissionで実現する中間成果を入力してください。',
          purpose: 'Quest達成に必要な中間成果を追加する',
          doneCondition: '複数のTaskを終え、中間成果を確認できたら完了です。',
          expectedOutput: '確認できる中間成果',
          reasonRequired: '既存のMissionでは扱えない成功条件を補います。',
          coveredSuccessConditions: const ['ユーザーが追加した成功条件'],
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
