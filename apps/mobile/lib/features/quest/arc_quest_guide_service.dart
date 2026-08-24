import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/config/supabase_config.dart';
import '../../core/estimation/effort_estimate.dart';
import '../mission/mission_model.dart';
import 'quest_guide_model.dart';
import 'quest_evaluation.dart';
import 'quest_dna.dart';
import 'quest_model.dart';
import 'planning_context.dart';
import 'quest_understanding.dart';
import 'mission_plan_quality.dart';

class ArcMissionCandidate {
  const ArcMissionCandidate({
    required this.title,
    required this.description,
    required this.guideType,
    required this.difficulty,
    this.effortEstimate,
    this.questEvaluation,
    this.planKey = '',
    this.purpose = '',
    this.doneCondition = '',
    this.expectedOutput = '',
    this.verificationType = 'self_check',
    String? action,
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
  }) : action = action ?? title;

  final String title;
  final String description;
  final GuideType guideType;
  final MissionDifficulty difficulty;
  final EffortEstimate? effortEstimate;
  final QuestEvaluation? questEvaluation;
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

  ArcMissionCandidate copyWith({
    String? planKey,
    String? title,
    String? description,
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
    GuideType? guideType,
    MissionDifficulty? difficulty,
    EffortEstimate? effortEstimate,
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
    return ArcMissionCandidate(
      planKey: planKey ?? this.planKey,
      title: title ?? this.title,
      description: description ?? this.description,
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
      guideType: guideType ?? this.guideType,
      difficulty: difficulty ?? this.difficulty,
      effortEstimate: effortEstimate ?? this.effortEstimate,
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
}

class ArcTaskCandidate {
  const ArcTaskCandidate({
    required this.planKey,
    required this.title,
    required this.action,
    required this.purpose,
    required this.doneCondition,
    required this.expectedOutput,
    required this.estimatedEffortMinutes,
    this.dependencyPlanKeys = const [],
    this.required = true,
    this.confidence = 0.5,
  });

  final String planKey;
  final String title;
  final String action;
  final String purpose;
  final String doneCondition;
  final String expectedOutput;
  final int estimatedEffortMinutes;
  final List<String> dependencyPlanKeys;
  final bool required;
  final double confidence;
}

class ArcQuestGuide {
  const ArcQuestGuide({
    required this.questId,
    required this.summary,
    required this.path,
    required this.cautions,
    required this.encouragement,
    required this.missionCandidates,
    required this.sourceType,
    this.effortEstimate,
    this.questEvaluation,
    this.questDna,
    this.questUnderstanding,
    this.planQuality,
    this.previewId,
    this.approvalToken,
    this.draftId,
    this.currentMissionClientId,
    this.currentTaskCandidates = const [],
  });

  final String questId;
  final String summary;
  final String path;
  final String cautions;
  final String encouragement;
  final List<ArcMissionCandidate> missionCandidates;
  final String sourceType;
  final EffortEstimate? effortEstimate;
  final QuestEvaluation? questEvaluation;
  final QuestDna? questDna;
  final QuestUnderstanding? questUnderstanding;
  final MissionPlanQuality? planQuality;
  final String? previewId;
  final String? approvalToken;
  final String? draftId;
  final String? currentMissionClientId;
  final List<ArcTaskCandidate> currentTaskCandidates;
}

abstract interface class ArcQuestGuideService {
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
  });

  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  });
}

class LocalArcQuestGuideService implements ArcQuestGuideService {
  const LocalArcQuestGuideService();

  @override
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
  }) async {
    throw StateError(
      'Gemini Planning APIを利用できません。入力内容は保持されています。接続を確認して再試行してください。',
    );
  }

  @override
  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  }) async {}
}

class SupabaseArcQuestGuideService implements ArcQuestGuideService {
  const SupabaseArcQuestGuideService({required this.client});

  final SupabaseClient client;

  @override
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Gemini Planning APIを利用できません。接続設定を確認してください。');
    }

    try {
      final response = await client.functions.invoke(
        'quest-planning-v2',
        body: {
          'mode': 'plan',
          'quest_id': quest.id,
          'wish': [
            quest.title,
            quest.description,
          ].where((value) => value.trim().isNotEmpty).join('\n'),
          'target_date': quest.targetDate?.toIso8601String(),
          'budget': planningContext?.budgetLabel,
          'available_time': planningContext?.weeklyMinutes == null
              ? null
              : {'weekly_minutes': planningContext!.weeklyMinutes},
          'experience': planningContext?.experience,
          'location': planningContext?.location,
          'constraints': [
            ...?planningContext?.preferences,
            ...?planningContext?.setbackReasons,
          ],
          'approved_context': planningContext?.consentGranted == true
              ? planningContext!.toPlanningJson()
              : null,
          'idempotency_key':
              'flutter-${quest.id}-${DateTime.now().toUtc().millisecondsSinceEpoch}',
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['status'] == 'needs_clarification') {
        final questions = _clarificationQuestions(data);
        throw StateError(
          questions.isEmpty
              ? 'Arcが航路を描くために、Questの条件をもう少し確認したがっています。'
              : questions.join('\n'),
        );
      }
      if (data['status'] != 'preview_ready' || data['preview'] is! Map) {
        throw StateError(_planningFailureMessage(data));
      }
      return _guideFromPlanningPreview(quest, data);
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError('ArcがMission構造を確認できませんでした。固定候補には置き換えず、もう一度試せます。');
    }
  }

  String _planningFailureMessage(Map<String, dynamic> data) {
    final passes = data['passes'] as List? ?? const [];
    for (final rawPass in passes.reversed) {
      if (rawPass is! Map) continue;
      final provider = rawPass['provider'];
      if (provider is! Map) continue;
      final error = provider['error'];
      if (error is! Map) continue;
      switch (error['code']) {
        case 'budget_exhausted':
          return '今月の航路づくり枠を使い切りました。入力は残っています。時間をおくか、Missionを手動で追加できます。';
        case 'ai_disabled':
          return '航路づくりを一時停止しています。入力は残っています。時間をおいて再試行してください。';
        case 'budget_unavailable':
          return '航路づくりの利用状況を確認できませんでした。入力を保ったまま再試行できます。';
      }
    }
    return 'Mission候補の品質確認を完了できませんでした。入力を保ったまま再試行できます。';
  }

  @override
  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  }) async {
    if (guide.previewId == null || guide.approvalToken == null) {
      throw StateError('承認できるMission draftがありません。');
    }
    await _recordApprovalFeedback(guide, candidates);
    final response = await client.functions.invoke(
      'quest-planning-v2',
      body: {
        'mode': 'approve',
        'preview_id': guide.previewId,
        'approval_token': guide.approvalToken,
        'approved_missions': [
          for (final candidate in candidates) _candidateToApproval(candidate),
        ],
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['status'] != 'approved') {
      throw StateError('Missionを確定できませんでした。候補は失われていません。');
    }
  }

  Future<void> _recordApprovalFeedback(
    ArcQuestGuide guide,
    List<ArcMissionCandidate> candidates,
  ) async {
    final draftId = guide.draftId;
    if (draftId == null) return;
    final approved = {for (final item in candidates) item.planKey: item};
    for (final original in guide.missionCandidates) {
      final current = approved[original.planKey];
      final event = current == null
          ? 'deleted'
          : current.title.trim() != original.title.trim() ||
                current.purpose.trim() != original.purpose.trim() ||
                current.doneCondition.trim() != original.doneCondition.trim()
          ? 'edited'
          : 'accepted';
      try {
        await client.rpc(
          'record_mission_candidate_feedback',
          params: {
            'p_draft_id': draftId,
            'p_client_id': original.planKey,
            'p_event_type': event,
            'p_metadata': {'source': 'mission_proposal_review'},
          },
        );
      } catch (_) {
        // Feedback must never block an explicitly approved plan.
      }
    }
  }

  ArcQuestGuide _guideFromPlanningPreview(
    Quest quest,
    Map<String, dynamic> data,
  ) {
    final preview = Map<String, dynamic>.from(data['preview'] as Map);
    final understanding = Map<String, dynamic>.from(
      preview['questUnderstanding'] as Map? ?? const {},
    );
    final contract = Map<String, dynamic>.from(
      preview['successContract'] as Map? ?? const {},
    );
    final strategy = Map<String, dynamic>.from(
      preview['strategicPlan'] as Map? ?? const {},
    );
    final plan = Map<String, dynamic>.from(
      preview['routeMissionPlan'] as Map? ?? const {},
    );
    final taskPlan = Map<String, dynamic>.from(
      preview['currentTaskPlan'] as Map? ?? const {},
    );
    final critic = Map<String, dynamic>.from(
      preview['missionCritic'] as Map? ?? const {},
    );
    final taskCritic = Map<String, dynamic>.from(
      preview['currentTaskCritic'] as Map? ?? const {},
    );
    final qualityGate = Map<String, dynamic>.from(
      preview['qualityGate'] as Map? ?? const {},
    );
    if (data['preview_id'] is! String ||
        data['approval_token'] is! String ||
        qualityGate['status'] != 'passed' ||
        qualityGate['version'] != 'qst-341-v1' ||
        critic['passed'] != true ||
        (critic['overallScore'] as num? ?? 0) < 85 ||
        taskCritic['passed'] != true ||
        (taskCritic['overallScore'] as num? ?? 0) < 85) {
      throw StateError('Mission候補の品質確認が完了していません。入力を保ったまま再試行できます。');
    }
    final criticById = <String, Map<String, dynamic>>{
      for (final raw in (critic['missionResults'] as List? ?? const []))
        if (raw is Map && raw['clientId'] is String)
          raw['clientId'] as String: Map<String, dynamic>.from(raw),
    };
    final candidates = <ArcMissionCandidate>[
      for (final raw in (plan['missions'] as List? ?? const []))
        if (raw is Map)
          _candidateFromPlanningData(
            Map<String, dynamic>.from(raw),
            criticById[(raw['clientId'] ?? '').toString()],
          ),
    ];
    final taskCandidates = <ArcTaskCandidate>[
      for (final raw in (taskPlan['tasks'] as List? ?? const []))
        if (raw is Map)
          _taskCandidateFromPlanningData(Map<String, dynamic>.from(raw)),
    ];
    final taskReviewIds = {
      for (final raw in (taskCritic['taskResults'] as List? ?? const []))
        if (raw is Map && raw['clientId'] is String && raw['passed'] == true)
          raw['clientId'] as String,
    };
    if (candidates.isEmpty ||
        criticById.length != candidates.length ||
        candidates.any(
          (candidate) => !_criticReviewPassed(criticById[candidate.planKey]),
        ) ||
        taskCandidates.isEmpty ||
        taskReviewIds.length != taskCandidates.length ||
        taskCandidates.any((task) => !taskReviewIds.contains(task.planKey))) {
      throw StateError('合格したMission候補がありません。Questの条件を追加して再試行してください。');
    }
    final evidence = _stringList(contract['successEvidence'], 8);
    final phases = _stringList(strategy['phases'], 10);
    final risks = _stringList(strategy['risks'], 8);
    return ArcQuestGuide(
      questId: quest.id,
      summary: (understanding['desiredOutcome'] as String?) ?? quest.title,
      path: phases.isEmpty ? 'Missionごとの中間成果を順に達成します。' : phases.join(' → '),
      cautions: risks.isEmpty ? '状況が変わったらArcと航路を見直せます。' : risks.join('\n'),
      encouragement: 'Questの成功条件から、意味のある中間成果だけを選びました。',
      missionCandidates: candidates,
      sourceType: 'gemini_mission_architecture_v1',
      questUnderstanding: QuestUnderstanding(
        originalWish: (understanding['originalWish'] as String?) ?? quest.title,
        questOutcome: (contract['questOutcome'] as String?) ?? quest.title,
        successEvidence: evidence.join('\n'),
        motivation: (understanding['motivation'] as String?) ?? '',
        currentState: (understanding['currentState'] as String?) ?? '',
        constraints: _stringList(understanding['constraints'], 12),
        knownResources: const [],
        unknowns: _stringList(understanding['unknowns'], 8),
        planningRisks: _stringList(understanding['risks'], 8),
        planningMode: QuestPlanningMode.project,
        assumptions: _stringList(understanding['assumptions'], 8),
      ),
      planQuality: MissionPlanQuality(
        score: ((critic['overallScore'] as num?)?.toDouble() ?? 0) / 100,
        generationVersion: 'qst-259-v1',
        criticPasses: 1,
        repairedMissionCount: _repairCount(data['passes']),
        generatedAt: DateTime.now().toUtc(),
      ),
      previewId: data['preview_id'] as String?,
      approvalToken: data['approval_token'] as String?,
      draftId: data['draft_id'] as String?,
      currentMissionClientId: taskPlan['missionClientId'] as String?,
      currentTaskCandidates: taskCandidates,
    );
  }

  bool _criticReviewPassed(Map<String, dynamic>? review) {
    if (review == null ||
        review['passed'] != true ||
        review['verdict'] != 'pass') {
      return false;
    }
    final scores = Map<String, dynamic>.from(
      review['scores'] as Map? ?? const {},
    );
    const minimums = <String, int>{
      'questRelevance': 90,
      'outcomeQuality': 85,
      'missionGranularity': 90,
      'successConditionQuality': 90,
      'personalization': 80,
      'nonTemplateQuality': 90,
      'uniqueness': 90,
      'sequencing': 80,
      'completenessContribution': 85,
      'taskSeparation': 95,
    };
    return minimums.entries.every(
      (entry) =>
          scores[entry.key] is num && (scores[entry.key] as num) >= entry.value,
    );
  }

  ArcTaskCandidate _taskCandidateFromPlanningData(Map<String, dynamic> data) {
    return ArcTaskCandidate(
      planKey: data['clientId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      action: data['action'] as String? ?? '',
      purpose: data['purpose'] as String? ?? '',
      doneCondition: data['doneCondition'] as String? ?? '',
      expectedOutput: data['expectedOutput'] as String? ?? '',
      estimatedEffortMinutes:
          (data['estimatedEffortMinutes'] as num?)?.round().clamp(1, 1440) ??
          30,
      dependencyPlanKeys: _stringList(data['dependencies'], 20),
      required: data['required'] != false,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }

  ArcMissionCandidate _candidateFromPlanningData(
    Map<String, dynamic> data,
    Map<String, dynamic>? review,
  ) {
    final scores = <String, int>{
      for (final entry in Map<String, dynamic>.from(
        review?['scores'] as Map? ?? const {},
      ).entries)
        if (entry.value is num) entry.key: (entry.value as num).round(),
    };
    return ArcMissionCandidate(
      planKey: data['clientId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['objective'] as String? ?? '',
      purpose: data['objective'] as String? ?? '',
      doneCondition: data['successCondition'] as String? ?? '',
      expectedOutput: data['expectedOutcome'] as String? ?? '',
      action: data['objective'] as String? ?? '',
      dependencyPlanKeys: _stringList(data['dependencies'], 20),
      guideType: GuideType.route,
      difficulty: MissionDifficulty.normal,
      priority: data['required'] == true
          ? MissionPriority.high
          : MissionPriority.normal,
      isOptional: data['required'] != true,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.5,
      estimatedDurationDays: (data['calendarDurationDays'] as num?)?.round(),
      reasonRequired: data['reasonRequired'] as String? ?? '',
      coveredSuccessConditions: _stringList(
        data['coveredSuccessConditions'],
        8,
      ),
      parallelizable: data['parallelizable'] == true,
      childTaskEstimate:
          (data['childTaskEstimate'] as num?)?.round().clamp(1, 30) ?? 2,
      referenceHints: _stringList(data['groundedFactRefs'], 12),
      sourceRequirement: data['requiresCurrentFacts'] == true
          ? 'grounded'
          : 'none',
      criticScores: scores,
      criticVerdict: review?['verdict'] as String? ?? 'reject',
    );
  }

  Map<String, Object?> _candidateToApproval(ArcMissionCandidate candidate) => {
    'clientId': candidate.planKey,
    'title': candidate.title.trim(),
    'objective': candidate.purpose.trim().isEmpty
        ? candidate.description.trim()
        : candidate.purpose.trim(),
    'successCondition': candidate.doneCondition.trim(),
    'expectedOutcome': candidate.expectedOutput.trim(),
    'reasonRequired': candidate.reasonRequired.trim(),
    'coveredSuccessConditions': candidate.coveredSuccessConditions,
    'groundedFactRefs': candidate.referenceHints,
    'requiresCurrentFacts': candidate.sourceRequirement == 'grounded',
    'calendarDurationDays': candidate.estimatedDurationDays ?? 0,
    'dependencies': candidate.dependencyPlanKeys,
    'required': !candidate.isOptional,
    'parallelizable': candidate.parallelizable,
    'childTaskEstimate': candidate.childTaskEstimate,
    'weight': 1,
    'confidence': candidate.confidence,
  };

  List<String> _clarificationQuestions(Map<String, dynamic> data) {
    final passes = data['passes'] as List? ?? const [];
    for (final pass in passes.reversed) {
      if (pass is! Map || pass['name'] != 'quest_understanding') continue;
      final output = pass['output'];
      if (output is Map) {
        return _stringList(output['clarificationQuestions'], 3);
      }
    }
    return const [];
  }

  int _repairCount(Object? passes) => (passes as List? ?? const [])
      .whereType<Map>()
      .where((pass) => pass['name'] == 'route_mission_repair')
      .length;

  List<String> _stringList(Object? value, int limit) {
    return (value as List?)
            ?.whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(limit)
            .toList(growable: false) ??
        const [];
  }
}
