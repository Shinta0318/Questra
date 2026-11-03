import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, SupabaseClient;

import '../../core/config/supabase_config.dart';
import '../../core/safety/ai_legal_failure.dart';
import '../../core/estimation/effort_estimate.dart';
import '../mission/mission_model.dart';
import 'quest_guide_model.dart';
import 'quest_evaluation.dart';
import 'quest_dna.dart';
import 'quest_model.dart';
import 'planning_context.dart';
import 'planning_attempt_repository.dart';
import 'quest_understanding.dart';
import 'mission_plan_quality.dart';

String? planningFailureMessageFromException(Object error) {
  if (error is! FunctionException) return null;
  if (error.status == 546 || error.status == 504) {
    return '航路づくりが途中で中断されました。Questと入力は残っています。今はMissionを手動で追加できます。';
  }
  if (error.details is! Map) return null;
  if (error.status == 400 &&
      (error.details as Map)['error'] == 'quest_wish_too_long') {
    return '航路に送る文章が長すぎます。Questの説明か追加回答を短くしてください。';
  }
  if (error.status == 400 &&
      (error.details as Map)['error'] == 'invalid_planning_context') {
    return '航路に使う条件を確認できません。入力を短くするか、設定を確認してから再試行してください。';
  }
  if (error.status == 400 &&
      (error.details as Map)['error'] == 'invalid_target_date') {
    return '希望達成日を確認できません。Questの期限を設定し直してから再試行してください。';
  }
  if (error.status == 403 &&
      (error.details as Map)['error'] ==
          'planning_preferences_consent_required') {
    return '保存した計画条件の利用許可を確認できません。計画設定を確認してください。Questの入力は残っています。';
  }
  if (error.status != 422 && error.status != 429 && error.status != 503) {
    return null;
  }
  final details = Map<String, dynamic>.from(error.details as Map);
  if (details['status'] != 'retryable_error' &&
      details['status'] != 'manual_path') {
    return null;
  }
  return planningFailureMessage(details);
}

bool planningAttemptChanged(Object error) =>
    error is FunctionException &&
    error.status == 409 &&
    error.details is Map &&
    (error.details as Map)['error'] == 'planning_attempt_changed';

bool planningCriticEvaluationInvalid(Object error) {
  if (error is! FunctionException || error.details is! Map) return false;
  final details = error.details as Map;
  if (details['status'] != 'retryable_error' || details['passes'] is! List) {
    return false;
  }
  return (details['passes'] as List).any((pass) {
    if (pass is! Map ||
        pass['name'] != 'mission_critic' && pass['name'] != 'task_critic') {
      return false;
    }
    final provider = pass['provider'];
    return provider is Map &&
        provider['error'] is Map &&
        (provider['error'] as Map)['code'] == 'semantic_invalid';
  });
}

String? planningApprovalFailureMessage(Object error) {
  if (error is! FunctionException || error.details is! Map) return null;
  return switch ((error.details as Map)['error']) {
    'consent_required' =>
      '利用条件への同意を確認できません。設定を確認してください。航路案と入力は残っています。',
    'original_planning_wish_missing' =>
      'この航路案は作成時の相談内容を確認できません。案を見送って、航路を作り直してください。',
    'original_planning_context_missing' =>
      'この航路案は作成時の条件を確認できません。案を見送って、航路を作り直してください。',
    'planning_context_changed' =>
      '航路案を作った後にQuestや計画条件が変わりました。案を見送って、最新の条件で作り直してください。',
    'planning_preferences_consent_required' =>
      '保存した計画条件の利用許可を確認できません。計画設定を確認してください。Questの入力は残っています。',
    'planning_context_unavailable' =>
      '今は計画条件を確認できません。候補は残っています。少し待ってから再試行してください。',
    'route_changed_since_preview' =>
      '提案後にMissionが変更されました。最新の航路を読み直して、もう一度作成してください。',
    'completed_mission_duplicate_in_plan' =>
      '完了済みMissionと重なる候補がありました。完了内容を保ったまま、もう一度作成してください。',
    'preview_already_approved_with_different_selection' =>
      '別の航路案が先に確定されました。Questを開き直して現在のMissionを確認してください。',
    'preview_not_approvable' => 'この航路案は期限切れか、すでに見送られています。新しい案を作成してください。',
    'approved_selection_not_found' ||
    'preview_stage_failed' => '編集した航路案を確認できませんでした。候補は残っています。少し待ってから再試行してください。',
    'approval_failed' => 'Missionを保存できたか確認できません。候補は残っています。少し待ってから再試行してください。',
    _ => null,
  };
}

String planningFailureMessage(Map<String, dynamic> data) {
  final codes = <Object?>[];
  final issues = data['issues'];
  if (issues is List) {
    for (final issue in issues.reversed) {
      if (issue is Map) codes.add(issue['code']);
    }
  }
  final passes = data['passes'];
  if (passes is List) {
    for (final pass in passes.reversed) {
      if (pass is! Map || pass['provider'] is! Map) continue;
      final provider = pass['provider'] as Map;
      if (provider['error'] is Map) {
        codes.add((provider['error'] as Map)['code']);
      }
    }
  }
  for (final code in codes) {
    switch (code) {
      case 'rate_limited':
        return 'Geminiの利用枠に達しました。入力は残っています。回復時刻は確認できないため、時間をおいて再試行するか、Missionを手動で追加できます。';
      case 'budget_exhausted':
        return '今月の航路づくり枠を使い切りました。入力は残っています。時間をおくか、Missionを手動で追加できます。';
      case 'ai_disabled':
        return '航路づくりを一時停止しています。入力は残っています。時間をおいて再試行してください。';
      case 'budget_unavailable':
        return '航路づくりの利用状況を確認できませんでした。入力を保ったまま再試行できます。';
      case 'timeout':
        return '航路づくりに時間がかかっています。入力は残っています。少し待ってから再試行してください。';
      case 'grounding_failed':
        return '最新情報を確認できなかったため、航路はまだ作成していません。入力を保ったまま再試行できます。';
      case 'semantic_invalid':
        return 'Arcの評価結果を確認できませんでした。航路は保存していません。入力を保ったまま再試行できます。';
      case 'critic_rejected':
        return 'Arcが作ったMission案は品質基準を満たしませんでした。航路は保存していません。Questの条件を見直して再試行するか、Missionを手動で追加できます。';
      case 'task_critic_rejected':
        return '最初のTask案が品質基準を満たしませんでした。航路は保存していません。条件を見直して再試行できます。';
    }
  }
  return 'Mission候補の品質確認を完了できませんでした。入力を保ったまま再試行できます。';
}

class PlanningRateLimitException implements Exception {
  const PlanningRateLimitException(this.message, this.retryAfter);

  final String message;
  final Duration retryAfter;

  @override
  String toString() => message;
}

class PlanningClarificationException implements Exception {
  const PlanningClarificationException(this.questions);

  final List<String> questions;
}

String planningWishWithAnswers(
  Quest quest,
  Map<String, String> clarificationAnswers,
) {
  final wish = [
    quest.title,
    quest.description,
  ].where((value) => value.trim().isNotEmpty).join('\n');
  final answers = clarificationAnswers.entries
      .where(
        (entry) => entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty,
      )
      .take(3)
      .map((entry) => '${entry.key.trim()} ${entry.value.trim()}')
      .toList();
  final composed = answers.isEmpty
      ? wish
      : '$wish\nArcとの確認:\n${answers.join('\n')}';
  if (composed.length > 1200) {
    throw StateError('航路に送る文章が長すぎます。Questの説明か追加回答を短くしてください。');
  }
  return composed;
}

Duration? planningRateLimitWait(Map<String, dynamic> data) {
  if (data['status'] != 'retryable_error') return null;
  final seconds = data['retryAfterSeconds'];
  if (seconds is! int || seconds < 1) return null;
  return Duration(seconds: seconds.clamp(1, 3600));
}

Map<String, Object?> planningContextPayload(PlanningContext? context) {
  if (context?.consentGranted != true) return const {};
  return {
    'budget': context!.budgetLabel,
    'available_time': context.weeklyMinutes == null
        ? null
        : {'weekly_minutes': context.weeklyMinutes},
    'experience': context.experience,
    'location': context.location,
    'constraints': [...context.preferences, ...context.setbackReasons],
    'approved_context': context.toPlanningJson(),
  };
}

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
    this.planningAttemptFingerprint,
    this.planningAttemptKey,
    this.currentMissionClientId,
    this.currentTaskCandidates = const [],
    this.replacesExistingRoute = false,
    this.existingMissionCount = 0,
    this.completedMissionCount = 0,
    this.replaceableMissionCount = 0,
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
  final String? planningAttemptFingerprint;
  final String? planningAttemptKey;
  final String? currentMissionClientId;
  final List<ArcTaskCandidate> currentTaskCandidates;
  final bool replacesExistingRoute;
  final int existingMissionCount;
  final int completedMissionCount;
  final int replaceableMissionCount;
}

abstract interface class ArcQuestGuideService {
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
    Map<String, String> clarificationAnswers = const {},
  });

  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  });

  Future<void> reject(ArcQuestGuide guide);
}

class LocalArcQuestGuideService implements ArcQuestGuideService {
  const LocalArcQuestGuideService();

  @override
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
    Map<String, String> clarificationAnswers = const {},
  }) async {
    throw StateError(
      'Gemini Planning APIを利用できません。入力内容は保持されています。接続を確認して再試行してください。',
    );
  }

  @override
  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  }) async {
    throw StateError('航路を確定できません。Gemini Planning APIの接続を確認して、もう一度試してください。');
  }

  @override
  Future<void> reject(ArcQuestGuide guide) async {}
}

class SupabaseArcQuestGuideService implements ArcQuestGuideService {
  SupabaseArcQuestGuideService({
    required this.client,
    PlanningAttemptRepository? attemptRepository,
  }) : _attempts = attemptRepository ?? SecurePlanningAttemptRepository();

  final SupabaseClient client;
  final PlanningAttemptRepository _attempts;

  @override
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
    Map<String, String> clarificationAnswers = const {},
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Gemini Planning APIを利用できません。接続設定を確認してください。');
    }
    if (clarificationAnswers.isNotEmpty &&
        planningContext?.consentGranted != true) {
      throw StateError('追加回答はまだ送信していません。Arcの航路設計に使う条件を確認してください。');
    }

    try {
      final ownerId = client.auth.currentUser?.id;
      final body = <String, Object?>{
        'mode': 'plan',
        'quest_id': quest.id,
        'wish': planningWishWithAnswers(quest, clarificationAnswers),
        'target_date': quest.targetDate?.toIso8601String(),
        ...planningContextPayload(planningContext),
      };
      final fingerprint = sha256
          .convert(utf8.encode(jsonEncode(body)))
          .toString();
      final attemptKey = await _attempts.loadOrCreate(
        ownerId,
        quest.id,
        fingerprint,
      );
      body['idempotency_key'] = attemptKey;
      Map<String, dynamic>? data;
      for (var step = 0; step < 24; step++) {
        try {
          final response = await client.functions.invoke(
            'quest-planning-v2',
            body: body,
          );
          data = Map<String, dynamic>.from(response.data as Map);
        } on FunctionException catch (error) {
          if (planningAttemptChanged(error)) {
            await _attempts.clear(ownerId, quest.id, fingerprint, attemptKey);
            throw StateError('Questの状態が変わりました。入力は残っています。もう一度航路づくりを試してください。');
          }
          if (planningCriticEvaluationInvalid(error)) {
            await _attempts.clear(ownerId, quest.id, fingerprint, attemptKey);
          }
          rethrow;
        }
        if (data['status'] != 'processing') break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (data == null || data['status'] == 'processing') {
        throw StateError('航路づくりはまだ完了していません。Questと入力は残っています。少し待ってから再試行してください。');
      }
      if (data['status'] == 'needs_clarification') {
        final questions = _clarificationQuestions(data);
        if (questions.isNotEmpty) {
          throw PlanningClarificationException(questions);
        }
        throw StateError('Arcが航路を描くために、Questの条件をもう少し確認したがっています。');
      }
      if (data['status'] != 'preview_ready' || data['preview'] is! Map) {
        final retryAfter = planningRateLimitWait(data);
        if (retryAfter != null) {
          throw PlanningRateLimitException(
            planningFailureMessage(data),
            retryAfter,
          );
        }
        throw StateError(planningFailureMessage(data));
      }
      return _guideFromPlanningPreview(
        quest,
        data,
        planningAttemptFingerprint: fingerprint,
        planningAttemptKey: attemptKey,
      );
    } catch (error) {
      if (error is StateError ||
          error is PlanningRateLimitException ||
          error is PlanningClarificationException) {
        rethrow;
      }
      final legalMessage = aiLegalFailureMessage(error);
      if (legalMessage != null) throw StateError(legalMessage);
      final planningMessage = planningFailureMessageFromException(error);
      if (planningMessage != null) {
        if (error is FunctionException && error.details is Map) {
          final details = Map<String, dynamic>.from(error.details as Map);
          final retryAfter = planningRateLimitWait(details);
          if (retryAfter != null) {
            throw PlanningRateLimitException(planningMessage, retryAfter);
          }
        }
        throw StateError(planningMessage);
      }
      throw StateError('ArcがMission構造を確認できませんでした。固定候補には置き換えず、もう一度試せます。');
    }
  }

  @override
  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  }) async {
    if (guide.previewId == null || guide.approvalToken == null) {
      throw StateError('承認できるMission draftがありません。');
    }
    final selectionChanged = approvalSelectionChanged(
      guide.missionCandidates,
      candidates,
    );
    final body = {
      'mode': 'approve',
      'preview_id': guide.previewId,
      'approval_token': guide.approvalToken,
      if (selectionChanged)
        'approved_missions': [
          for (final candidate in candidates) _candidateToApproval(candidate),
        ],
    };
    Map<String, dynamic>? data;
    for (var step = 0; step < 16; step++) {
      try {
        final response = await client.functions.invoke(
          'quest-planning-v2',
          body: body,
        );
        data = Map<String, dynamic>.from(response.data as Map);
      } on FunctionException catch (error) {
        final message = planningApprovalFailureMessage(error);
        if (message != null) throw StateError(message);
        rethrow;
      }
      if (data['status'] != 'processing') break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (data == null || data['status'] == 'processing') {
      throw StateError('承認内容の確認がまだ完了していません。候補は残っています。少し待ってから再試行してください。');
    }
    if (data['error'] == 'route_changed_since_preview') {
      throw StateError('提案後にMissionが変更されました。最新の航路を読み直して、もう一度作成してください。');
    }
    if (data['error'] == 'completed_mission_duplicate_in_plan') {
      throw StateError('完了済みMissionと重なる候補がありました。完了内容を保ったまま、もう一度作成してください。');
    }
    if (data['error'] == 'original_planning_wish_missing') {
      throw StateError('この航路案は作成時の相談内容を確認できません。案を見送って、航路を作り直してください。');
    }
    if (data['error'] == 'original_planning_context_missing' ||
        data['error'] == 'planning_context_changed') {
      throw StateError(
        data['error'] == 'planning_context_changed'
            ? '航路案を作った後にQuestや計画条件が変わりました。案を見送って、最新の条件で作り直してください。'
            : 'この航路案は作成時の条件を確認できません。案を見送って、航路を作り直してください。',
      );
    }
    if (data['status'] != 'approved') {
      throw StateError('Missionを確定できませんでした。候補は失われていません。');
    }
    await _recordApprovalFeedback(guide, candidates);
    await _clearPlanningAttempt(guide);
  }

  @override
  Future<void> reject(ArcQuestGuide guide) async {
    if (guide.previewId == null && guide.approvalToken == null) return;
    if (guide.previewId == null || guide.approvalToken == null) {
      throw StateError('この航路案を確認できませんでした。画面を開き直してください。');
    }
    try {
      final response = await client.functions.invoke(
        'quest-planning-v2',
        body: {
          'mode': 'reject',
          'preview_id': guide.previewId,
          'approval_token': guide.approvalToken,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['status'] != 'rejected') {
        throw StateError('航路案を見送れませんでした。もう一度お試しください。');
      }
    } on FunctionException catch (error) {
      if (error.status == 409) {
        throw StateError('この航路案はすでに確定または見送り済みです。画面を開き直してください。');
      }
      throw StateError('航路案を見送れませんでした。通信状態を確認して再試行してください。');
    }
    await _clearPlanningAttempt(guide);
  }

  Future<void> _clearPlanningAttempt(ArcQuestGuide guide) async {
    final fingerprint = guide.planningAttemptFingerprint;
    final attemptKey = guide.planningAttemptKey;
    if (fingerprint == null || attemptKey == null) return;
    await _attempts.clear(
      client.auth.currentUser?.id,
      guide.questId,
      fingerprint,
      attemptKey,
    );
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
    Map<String, dynamic> data, {
    String? planningAttemptFingerprint,
    String? planningAttemptKey,
  }) {
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
    final routeApplication = Map<String, dynamic>.from(
      preview['routeApplication'] as Map? ?? const {},
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
      planningAttemptFingerprint: planningAttemptFingerprint,
      planningAttemptKey: planningAttemptKey,
      currentMissionClientId: taskPlan['missionClientId'] as String?,
      currentTaskCandidates: taskCandidates,
      replacesExistingRoute:
          routeApplication['applicationMode'] == 'replace_remaining',
      existingMissionCount:
          (routeApplication['existingMissionCount'] as num?)?.toInt() ?? 0,
      completedMissionCount:
          (routeApplication['completedMissionCount'] as num?)?.toInt() ?? 0,
      replaceableMissionCount:
          (routeApplication['replaceableMissionCount'] as num?)?.toInt() ?? 0,
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

bool approvalSelectionChanged(
  List<ArcMissionCandidate> original,
  List<ArcMissionCandidate> selected,
) {
  if (original.length != selected.length) return true;
  for (var index = 0; index < original.length; index++) {
    if (jsonEncode(_candidateToApproval(original[index])) !=
        jsonEncode(_candidateToApproval(selected[index]))) {
      return true;
    }
  }
  return false;
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
