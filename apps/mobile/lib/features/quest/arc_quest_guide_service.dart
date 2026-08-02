import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/config/supabase_config.dart';
import '../../core/estimation/effort_estimate.dart';
import '../../core/estimation/effort_estimation_service.dart';
import '../mission/mission_model.dart';
import '../mission/mission_plan_graph_service.dart';
import 'quest_guide_model.dart';
import 'quest_evaluation.dart';
import 'quest_dna.dart';
import 'quest_evaluation_service.dart';
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
    final candidates = MissionPlanGraphService.normalize(
      _adaptiveFallbackCandidates(quest, planningContext),
    );
    final evaluation = QuestEvaluationService.fallback(
      quest: quest,
      missionCount: candidates.length,
      missionDurationDays: candidates.map(
        (candidate) => candidate.estimatedDurationDays,
      ),
    );
    return ArcQuestGuide(
      questId: quest.id,
      summary:
          '「${quest.title}」は、${quest.category}の星へ向かう${quest.difficulty.label}Questです。${_descriptionHint(quest)}',
      path: _planningPath(planningContext),
      cautions:
          '最初から完璧な計画にしすぎないでください。難所はMissionを小さく分け、迷ったらTrailに現在地を書き残すのが安全です。',
      encouragement:
          'キャプテン、このQuestはもう星図に灯っています。最初の一歩は小さくて大丈夫。Arcは航路の変化を一緒に見ています。',
      missionCandidates: candidates,
      sourceType: 'local_arc_quest_guide',
      effortEstimate: EffortEstimationService.forQuest(
        title: quest.title,
        category: quest.category,
        missionCount: candidates.length,
      ),
      questEvaluation: evaluation,
      questDna: QuestDna.fallback(quest),
      questUnderstanding: QuestUnderstanding(
        originalWish: quest.title,
        questOutcome: '${quest.title}を実現する',
        successEvidence: '${quest.title}を達成したと確認し、Trailへ記録できる状態',
        motivation: quest.description,
        currentState: '現在地は未確認',
        constraints: const [],
        knownResources: const [],
        unknowns: const ['成功条件と利用できる時間を確認する'],
        planningRisks: const ['未確認の条件を事実として扱わない'],
        planningMode: QuestPlanningMode.project,
        assumptions: const ['詳細が分かるまで最小の確認航路を使う'],
      ),
      planQuality: MissionPlanQuality(
        score: 0.72,
        generationVersion: 'local_quest_guide_v3',
        criticPasses: 0,
        repairedMissionCount: 0,
        generatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  }) async {}

  String _descriptionHint(Quest quest) {
    if (quest.description.trim().isEmpty) {
      return '目的の背景は、これからTrailで少しずつ鮮明にできます。';
    }
    return '背景には「${quest.description.trim()}」があります。';
  }

  String _planningPath(PlanningContext? context) {
    final weeklyMinutes = context?.consentGranted == true
        ? context?.weeklyMinutes
        : null;
    if (weeklyMinutes != null && weeklyMinutes > 0) {
      return '週$weeklyMinutes分のペースを上限に、まず目的地と今日の小さなMissionを決めます。Trailへ気づきを残し、無理のない量へ航路を調整しましょう。';
    }
    return 'まず目的地を一文で固定し、今日できる小さなMissionを選びます。次にTrailへ気づきを残し、3日ごとに進み方を見直しましょう。';
  }

  List<ArcMissionCandidate> _adaptiveFallbackCandidates(
    Quest quest,
    PlanningContext? context,
  ) {
    final title = quest.title.trim();
    final target = quest.targetDate == null
        ? '希望する時期'
        : '${quest.targetDate!.year}年${quest.targetDate!.month}月';
    final explicitConditions = context?.consentGranted == true
        ? [
            if ((context?.weeklyMinutes ?? 0) > 0)
              '週${context!.weeklyMinutes}分',
            if (context?.budgetLabel?.trim().isNotEmpty == true)
              '予算 ${context!.budgetLabel!.trim()}',
            if (context?.experience?.trim().isNotEmpty == true)
              '経験 ${context!.experience!.trim()}',
          ].join('、')
        : '';
    return [
      ArcMissionCandidate(
        planKey: 'success-contract',
        title: '達成したと分かる状態を決める',
        purpose: 'Questの目的地を明確にする',
        description: '「$title」で何ができれば達成かを一文で記録したら完了です。',
        doneCondition: '達成判定を一文で記録する',
        expectedOutput: 'Questの成功条件',
        verificationType: 'self_check',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.easy,
        priority: MissionPriority.critical,
        category: '設計',
        estimatedDurationDays: 1,
      ),
      ArcMissionCandidate(
        planKey: 'constraints',
        title: '今の条件と不明点を分ける',
        purpose: '推測と事実を分ける',
        description: explicitConditions.isEmpty
            ? '使える時間、予算、場所、$target、不明点を分けて記録したら完了です。'
            : '登録済みの条件（$explicitConditions）と、$targetまでの不明点を分けて記録したら完了です。',
        doneCondition: '条件と不明点を別々に記録する',
        expectedOutput: '確認済み条件と質問の一覧',
        verificationType: 'artifact',
        dependencyPlanKeys: const ['success-contract'],
        guideType: GuideType.knowledge,
        difficulty: MissionDifficulty.easy,
        priority: MissionPriority.high,
        category: '確認',
        estimatedDurationDays: 1,
      ),
      const ArcMissionCandidate(
        planKey: 'source-check',
        title: '最初に確認する情報源を決める',
        purpose: '変わりやすい情報を安全に確かめる',
        description: '公式または専門家の確認先と確認日を一つ記録したら完了です。',
        doneCondition: '確認先と確認日を記録する',
        expectedOutput: '確認可能な参照先',
        verificationType: 'official_source',
        dependencyPlanKeys: ['constraints'],
        guideType: GuideType.knowledge,
        difficulty: MissionDifficulty.easy,
        priority: MissionPriority.high,
        category: '確認',
        estimatedDurationDays: 2,
      ),
      const ArcMissionCandidate(
        planKey: 'first-action',
        title: '今日の最小の一歩を予定する',
        purpose: 'Questを実行へ移す',
        description: '15分から始められる行動、実行日時、完了の印を決めたら完了です。',
        doneCondition: '日時付きの最初の行動を決める',
        expectedOutput: '今日のMission予定',
        verificationType: 'artifact',
        dependencyPlanKeys: ['constraints'],
        guideType: GuideType.training,
        difficulty: MissionDifficulty.easy,
        priority: MissionPriority.normal,
        category: '実行',
        estimatedDurationDays: 1,
      ),
    ];
  }

  // Kept temporarily for migration comparison; production fallback no longer
  // calls category-derived Mission content.
  // ignore: unused_element
  List<ArcMissionCandidate> _missionCandidates(Quest quest) {
    if (RegExp(r'(片付|掃除|整理|一冊読む|一回作る)').hasMatch(quest.title)) {
      return [
        ArcMissionCandidate(
          planKey: 'scope',
          title: '${quest.title}の完了状態を決める',
          purpose: '終わりの基準を明確にする',
          description: '達成したと判断できる状態を一文で書いたら完了です。',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
          priority: MissionPriority.high,
          estimatedDurationDays: 1,
        ),
        const ArcMissionCandidate(
          planKey: 'execute',
          title: '必要な作業を一度実行する',
          purpose: 'Questの中心行動を終える',
          description: '決めた完了条件まで作業を進めたら完了です。',
          dependencyPlanKeys: ['scope'],
          guideType: GuideType.training,
          difficulty: MissionDifficulty.normal,
          priority: MissionPriority.critical,
          estimatedDurationDays: 2,
        ),
        const ArcMissionCandidate(
          planKey: 'review',
          title: '結果を確認してTrailへ残す',
          purpose: '達成を確認して次に活かす',
          description: '完了状態を確認し、気づきをTrailへ一つ残したら完了です。',
          dependencyPlanKeys: ['execute'],
          guideType: GuideType.training,
          difficulty: MissionDifficulty.easy,
          priority: MissionPriority.normal,
          estimatedDurationDays: 1,
        ),
      ];
    }
    if (RegExp(r'(海外移住|起業|会社を作|長期留学)').hasMatch(quest.title)) {
      return _complexFallback(quest);
    }
    if (quest.category == '旅行' ||
        RegExp(r'(旅行|旅|海外|行く|訪れ)').hasMatch(quest.title)) {
      return const [
        ArcMissionCandidate(
          title: '旅の目的と候補日を決める',
          description: '体験したいことを3つ、出発日と帰着日の候補を2組書いたら完了です。',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
        ArcMissionCandidate(
          title: '旅券と入国条件を公式情報で確認する',
          description: '旅券の有効期限と最新の入国条件を公式サイトで確認し、確認日と参照先を残したら完了です。',
          guideType: GuideType.knowledge,
          difficulty: MissionDifficulty.easy,
        ),
        ArcMissionCandidate(
          title: '旅行予算の上限を決める',
          description: '交通、宿泊、食事、体験、予備費の上限を分け、合計予算を決めたら完了です。',
          guideType: GuideType.resource,
          difficulty: MissionDifficulty.easy,
        ),
        ArcMissionCandidate(
          title: '移動手段を3案比較する',
          description: '出発地から目的地までの3案を、料金、所要時間、変更条件で比較したら完了です。',
          guideType: GuideType.knowledge,
          difficulty: MissionDifficulty.normal,
        ),
        ArcMissionCandidate(
          title: '宿泊エリアと宿を比較する',
          description: '希望エリアを2つ選び、各エリアの宿を料金、移動、安全面で比較したら完了です。',
          guideType: GuideType.resource,
          difficulty: MissionDifficulty.normal,
        ),
        ArcMissionCandidate(
          title: '日ごとの旅程を組む',
          description: '移動時間を含め、各日に必須1件と余裕があれば行く1件を配置したら完了です。',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.normal,
        ),
        ArcMissionCandidate(
          title: '必要な予約を確定する',
          description: '交通、宿泊、日時指定の体験を一覧にし、予約期限と変更条件を確認したら完了です。',
          guideType: GuideType.opportunity,
          difficulty: MissionDifficulty.normal,
        ),
        ArcMissionCandidate(
          title: '現地の通信と移動方法を決める',
          description: '通信手段、空港からの移動、現地交通の支払い方法を一つずつ決めたら完了です。',
          guideType: GuideType.knowledge,
          difficulty: MissionDifficulty.easy,
        ),
        ArcMissionCandidate(
          title: '保険・健康・緊急連絡先を準備する',
          description: '保険の要否を判断し、常備薬、緊急連絡先、重要書類の控えをそろえたら完了です。',
          guideType: GuideType.resource,
          difficulty: MissionDifficulty.easy,
        ),
        ArcMissionCandidate(
          title: '持ち物を最終確認する',
          description: '必需品、現地用、機内用の3区分でリストを作り、出発前日に確認したら完了です。',
          guideType: GuideType.training,
          difficulty: MissionDifficulty.easy,
        ),
      ];
    }
    return [
      ArcMissionCandidate(
        title: '${quest.title}の完了条件を決める',
        description: '達成したと言える状態、期限、優先事項を一文ずつ記録したら完了です。',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.easy,
      ),
      const ArcMissionCandidate(
        title: '期限と前提条件を確認する',
        description: '変更されやすい条件を公式情報で確認し、参照先と確認日を残したら完了です。',
        guideType: GuideType.knowledge,
        difficulty: MissionDifficulty.easy,
      ),
      const ArcMissionCandidate(
        title: '使える予算と時間を決める',
        description: '上限予算と確保できる時間を数字で決めたら完了です。',
        guideType: GuideType.resource,
        difficulty: MissionDifficulty.easy,
      ),
      const ArcMissionCandidate(
        title: '選択肢を3つ比較する',
        description: '費用、時間、利点、注意点の同じ項目で3案を比較したら完了です。',
        guideType: GuideType.knowledge,
        difficulty: MissionDifficulty.normal,
      ),
      const ArcMissionCandidate(
        title: '進め方と日程を組み立てる',
        description: '準備、実行、振り返りの締切を決めたら完了です。',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.normal,
      ),
      const ArcMissionCandidate(
        title: '必要な予約や協力を整理する',
        description: '予約、申込み、相談相手を期限付きで一覧にしたら完了です。',
        guideType: GuideType.opportunity,
        difficulty: MissionDifficulty.normal,
      ),
      const ArcMissionCandidate(
        title: '不足する道具と情報をそろえる',
        description: '必要な物、資料、連絡手段をチェックリストにしたら完了です。',
        guideType: GuideType.resource,
        difficulty: MissionDifficulty.easy,
      ),
      const ArcMissionCandidate(
        title: 'リスクと代替案を決める',
        description: '主な問題を3つ挙げ、予防策と代替案を決めたら完了です。',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.normal,
      ),
      const ArcMissionCandidate(
        title: '最初の実行日を確定する',
        description: '最初に動く日時、場所、行動をカレンダーへ登録したら完了です。',
        guideType: GuideType.training,
        difficulty: MissionDifficulty.easy,
      ),
      const ArcMissionCandidate(
        title: 'Trailへ振り返りを残す',
        description: '良かった点、迷った点、次に変える点を一つずつ記録したら完了です。',
        guideType: GuideType.training,
        difficulty: MissionDifficulty.easy,
      ),
    ];
  }

  // ignore: unused_element
  List<ArcMissionCandidate> _complexFallback(Quest quest) {
    const stages = [
      '達成条件を定義する',
      '現在地との差を整理する',
      '法的な前提を公式情報で確認する',
      '必要な費用を見積もる',
      '資金計画を作る',
      '必要な技能を洗い出す',
      '最初の技能を学ぶ',
      '協力者へ相談する',
      '選択肢を比較する',
      '主要な方針を決める',
      '申請や契約の準備をする',
      '小さく試行する',
      '試行結果を評価する',
      '不足を補う',
      '実行日程を確定する',
      '本番を実行する',
      '結果と課題を確認する',
      'Trailへ学びを残す',
    ];
    return [
      for (var index = 0; index < stages.length; index++)
        ArcMissionCandidate(
          planKey: 'phase-${index + 1}',
          title: '${quest.title}: ${stages[index]}',
          purpose: '${quest.title}を段階的に前進させる',
          description: '${stages[index]}ための成果物または判断を一つ残したら完了です。',
          dependencyPlanKeys: index == 0 ? const [] : ['phase-$index'],
          guideType: index < 4 ? GuideType.knowledge : GuideType.route,
          difficulty: index < 6
              ? MissionDifficulty.easy
              : MissionDifficulty.normal,
          priority: index < 3 ? MissionPriority.high : MissionPriority.normal,
          category: index < 4 ? '調査' : '実行',
          estimatedDurationDays: index < 4 ? 3 : 14,
        ),
    ];
  }
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
        throw StateError('Mission候補の品質確認を完了できませんでした。入力を保ったまま再試行できます。');
      }
      return _guideFromPlanningPreview(quest, data);
    } catch (error) {
      if (error is StateError) rethrow;
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
    final critic = Map<String, dynamic>.from(
      preview['missionCritic'] as Map? ?? const {},
    );
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
    if (candidates.isEmpty) {
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
      currentMissionClientId:
          (preview['currentTaskPlan'] as Map?)?['missionClientId'] as String?,
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
      criticScores: scores,
      criticVerdict: review?['verdict'] as String? ?? 'pass',
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
