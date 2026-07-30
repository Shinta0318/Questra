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
    this.parentPlanKey,
    this.dependencyPlanKeys = const [],
    this.priority = MissionPriority.normal,
    this.category = '実行',
    this.estimatedCostLabel,
    this.referenceHints = const [],
    this.enterpriseSupportHints = const [],
    this.difficultyScore,
    this.estimatedDurationDays,
  });

  final String title;
  final String description;
  final GuideType guideType;
  final MissionDifficulty difficulty;
  final EffortEstimate? effortEstimate;
  final QuestEvaluation? questEvaluation;
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

  ArcMissionCandidate copyWith({
    String? planKey,
    String? title,
    String? description,
    String? purpose,
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
  }) {
    return ArcMissionCandidate(
      planKey: planKey ?? this.planKey,
      title: title ?? this.title,
      description: description ?? this.description,
      purpose: purpose ?? this.purpose,
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
}

abstract interface class ArcQuestGuideService {
  Future<ArcQuestGuide> generate({required Quest quest});
}

class LocalArcQuestGuideService implements ArcQuestGuideService {
  const LocalArcQuestGuideService();

  @override
  Future<ArcQuestGuide> generate({required Quest quest}) async {
    final candidates = MissionPlanGraphService.normalize(
      _missionCandidates(quest),
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
      path:
          'まず目的地を一文で固定し、今日できる小さなMissionを選びます。次にTrailへ気づきを残し、3日ごとに進み方を見直しましょう。',
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
    );
  }

  String _descriptionHint(Quest quest) {
    if (quest.description.trim().isEmpty) {
      return '目的の背景は、これからTrailで少しずつ鮮明にできます。';
    }
    return '背景には「${quest.description.trim()}」があります。';
  }

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
  const SupabaseArcQuestGuideService({
    required this.client,
    this.fallback = const LocalArcQuestGuideService(),
  });

  final SupabaseClient client;
  final ArcQuestGuideService fallback;

  @override
  Future<ArcQuestGuide> generate({required Quest quest}) async {
    if (!SupabaseConfig.isConfigured) {
      return fallback.generate(quest: quest);
    }

    try {
      final feedbackSignals = await _loadPlanningSignals(quest.category);
      final response = await client.functions.invoke(
        'arc-quest-guide',
        body: {
          'quest': {
            'id': quest.id,
            'title': quest.title,
            'description': quest.description,
            'difficulty': quest.difficulty.storageKey,
            'category': quest.category,
            'target_date': quest.targetDate?.toIso8601String(),
            'planning_context': _planningContextFromDescription(
              quest.description,
            ),
          },
          'planning_feedback': feedbackSignals,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final parsedCandidates =
          (data['mission_candidates'] as List?)
              ?.map((item) => _candidateFromData(item))
              .whereType<ArcMissionCandidate>()
              .take(MissionPlanGraphService.maxMissionCount)
              .toList(growable: false) ??
          const [];
      final candidates = MissionPlanGraphService.normalize(parsedCandidates);
      if (candidates.length < MissionPlanGraphService.minMissionCount) {
        return fallback.generate(quest: quest);
      }
      return ArcQuestGuide(
        questId: quest.id,
        summary: data['summary'] as String? ?? 'Questの輪郭を整理しました。',
        path: data['path'] as String? ?? '小さなMissionから航路を作りましょう。',
        cautions: data['cautions'] as String? ?? '無理なく小さく進めましょう。',
        encouragement: data['encouragement'] as String? ?? 'この一歩は、ちゃんと星図に残ります。',
        missionCandidates: candidates,
        sourceType: data['source_type'] as String? ?? 'arc_quest_guide',
        effortEstimate:
            _estimateFromData(data['effort_estimate']) ??
            EffortEstimationService.forQuest(
              title: quest.title,
              category: quest.category,
              missionCount: candidates.length,
            ),
        questEvaluation:
            QuestEvaluation.fromJson(data['quest_evaluation']) ??
            QuestEvaluationService.fallback(
              quest: quest,
              missionCount: candidates.length,
              missionDurationDays: candidates.map(
                (candidate) => candidate.estimatedDurationDays,
              ),
            ),
        questDna:
            QuestDna.fromJson(data['quest_dna']) ?? QuestDna.fallback(quest),
      );
    } catch (_) {
      return fallback.generate(quest: quest);
    }
  }

  Future<List<Map<String, Object?>>> _loadPlanningSignals(
    String category,
  ) async {
    if (client.auth.currentUser == null) return const [];
    try {
      final rows = await client
          .from('quest_planning_feedback')
          .select(
            'category_key,generated_count,accepted_count,edited_count,target_window',
          )
          .eq('category_key', category.trim().toLowerCase())
          .order('created_at', ascending: false)
          .limit(8);
      return rows
          .map<Map<String, Object?>>((row) => Map<String, Object?>.from(row))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  ArcMissionCandidate? _candidateFromData(Object? item) {
    if (item is! Map) {
      return null;
    }
    final data = Map<String, dynamic>.from(item);
    final title = data['title'] as String?;
    final description = data['description'] as String?;
    if (title == null || description == null) {
      return null;
    }
    return ArcMissionCandidate(
      planKey: data['plan_key'] as String? ?? '',
      title: title,
      description: description,
      purpose: data['purpose'] as String? ?? '',
      parentPlanKey: data['parent_plan_key'] as String?,
      dependencyPlanKeys: _stringList(data['dependency_plan_keys'], 12),
      guideType: _guideTypeFromValue(data['guide_type'] as String?),
      difficulty: _difficultyFromValue(data['difficulty'] as String?),
      priority: _priorityFromValue(data['priority'] as String?),
      category: data['category'] as String? ?? '実行',
      estimatedCostLabel: data['estimated_cost'] as String?,
      referenceHints: _stringList(data['reference_hints'], 6),
      enterpriseSupportHints: _stringList(data['enterprise_support_hints'], 4),
      difficultyScore: (data['difficulty_score'] as num?)?.round().clamp(1, 5),
      estimatedDurationDays: (data['estimated_duration_days'] as num?)
          ?.round()
          .clamp(1, 3650),
      effortEstimate:
          _estimateFromData(data['effort_estimate']) ??
          EffortEstimationService.forMission(
            title: title,
            description: description,
          ),
    );
  }

  EffortEstimate? _estimateFromData(Object? value) {
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);
    final activeMinutes = (data['active_effort_minutes'] as num?)?.round();
    final calendarDays = (data['calendar_days'] as num?)?.round();
    if (activeMinutes == null || calendarDays == null) return null;
    return EffortEstimate(
      difficultyBand: data['difficulty_band'] as String? ?? '標準',
      activeEffortMinutes: activeMinutes.clamp(15, 100000),
      calendarDays: calendarDays.clamp(1, 3650),
      confidence: (data['confidence'] as num?)?.toDouble().clamp(0, 1) ?? 0.4,
      rationale: data['rationale'] as String? ?? 'Arcによる推定です。',
      version: data['version'] as String? ?? 'effort-v1',
    );
  }

  GuideType _guideTypeFromValue(String? value) {
    return GuideType.values.firstWhere(
      (guideType) => guideType.name == value,
      orElse: () => GuideType.route,
    );
  }

  MissionDifficulty _difficultyFromValue(String? value) {
    return MissionDifficulty.values.firstWhere(
      (difficulty) => difficulty.name == value,
      orElse: () => MissionDifficulty.easy,
    );
  }

  MissionPriority _priorityFromValue(String? value) {
    return MissionPriority.values.firstWhere(
      (priority) => priority.name == value,
      orElse: () => MissionPriority.normal,
    );
  }

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

String? _planningContextFromDescription(String description) {
  const marker = '航路条件:';
  final markerIndex = description.indexOf(marker);
  if (markerIndex < 0) return null;
  final context = description.substring(markerIndex + marker.length).trim();
  return context.isEmpty ? null : context;
}
