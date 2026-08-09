import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/config/supabase_config.dart';
import '../../core/performance/performance_limits.dart';
import '../../core/validation/input_validators.dart';
import '../arc_memory/arc_memory_model.dart';
import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../quest/quest_clarification_service.dart';
import '../task/task_model.dart';
import '../trail/trail_model.dart';
import 'arc_quest_change_proposal.dart';

class ArcChatMessage {
  const ArcChatMessage({
    required this.text,
    required this.fromArc,
    required this.createdAt,
  });

  final String text;
  final bool fromArc;
  final DateTime createdAt;
}

class ArcChatContext {
  const ArcChatContext({
    required this.activeQuests,
    required this.recentMissions,
    this.recentTasks = const [],
    required this.recentTrails,
    required this.memories,
  });

  final List<Quest> activeQuests;
  final List<Mission> recentMissions;
  final List<QuestraTask> recentTasks;
  final List<Trail> recentTrails;
  final List<ArcMemory> memories;
}

class ArcChatResponse {
  const ArcChatResponse({
    required this.message,
    required this.sourceType,
    this.quickActions = const [],
    this.questSuggestion,
    this.questChanges = const [],
    this.clarificationQuestions = const [],
  });

  final String message;
  final String sourceType;
  final List<String> quickActions;
  final ArcQuestSuggestion? questSuggestion;
  final List<ArcQuestChangeProposal> questChanges;
  final List<QuestClarificationQuestion> clarificationQuestions;
}

class ArcQuestSuggestion {
  const ArcQuestSuggestion({
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.sourceInput,
    this.motivation = '',
    this.successCondition = '',
    this.realityFrame = 'uncertain',
    this.reframedOutcome,
  });

  final String title;
  final String description;
  final String category;
  final QuestDifficulty difficulty;
  final String sourceInput;
  final String motivation;
  final String successCondition;
  final String realityFrame;
  final String? reframedOutcome;
}

abstract interface class ArcChatService {
  Future<ArcChatResponse> send({
    required String userMessage,
    required List<ArcChatMessage> history,
    required ArcChatContext context,
  });
}

class LocalArcChatService implements ArcChatService {
  const LocalArcChatService();

  @override
  Future<ArcChatResponse> send({
    required String userMessage,
    required List<ArcChatMessage> history,
    required ArcChatContext context,
  }) async {
    final quest = context.activeQuests.isEmpty
        ? null
        : context.activeQuests.first;
    final trail = context.recentTrails.isEmpty
        ? null
        : context.recentTrails.first;
    final task = context.recentTasks.where((item) => item.isOpen).firstOrNull;
    final suggestion = inferArcQuestSuggestion(userMessage);
    final clarificationQuestions =
        suggestion == null || context.activeQuests.isNotEmpty
        ? const <QuestClarificationQuestion>[]
        : QuestClarificationService.resolve(
            input: suggestion.sourceInput,
            category: suggestion.category,
            targetDate: null,
          );
    final questChanges = _inferLocalQuestChanges(userMessage, context);
    final hasConcern = RegExp(r'不安|心配|怖|疲れ|つら|しんど|落ち込').hasMatch(userMessage);
    final message = switch ((hasConcern, quest, task, trail, suggestion)) {
      (true, _, _, _, _) => '少し気がかりなんだね。いちばん気になっているのは、どの部分？',
      (false, final Quest activeQuest, final QuestraTask nextTask, _, _) =>
        '「${activeQuest.title}」の次のTaskは「${nextTask.title}」だね。'
            '完了条件は「${nextTask.doneCondition}」。どこから一緒に整えようか？',
      (false, final Quest activeQuest, null, final Trail recentTrail, _) =>
        '「${recentTrail.title}」まで進んだんだね。'
            '「${activeQuest.title}」の次の一歩を小さくするなら、今どこで迷ってる？',
      (false, final Quest activeQuest, null, null, _) =>
        '「${activeQuest.title}」を進めているんだね。'
            '今日は、どの部分を一緒に整理しようか？',
      (false, null, _, _, final ArcQuestSuggestion questSuggestion) =>
        clarificationQuestions.isEmpty
            ? 'いいね。「${questSuggestion.title}」として航路を描けそうだよ。'
            : 'いいね。「${questSuggestion.title}」を航路にする前に、まず、'
                  '${clarificationQuestions.first.label}',
      _ => 'そうなんだ。今いちばん整理したいことを、一つだけ教えてくれる？',
    };

    return ArcChatResponse(
      message: message,
      sourceType: 'local_fallback',
      quickActions: const [
        'やりたいことを相談',
        'Questを作る',
        '今日の一歩を決める',
        '計画を見直す',
        '情報を調べる',
      ],
      questSuggestion: suggestion,
      questChanges: questChanges,
      clarificationQuestions: clarificationQuestions,
    );
  }
}

class SupabaseArcChatService implements ArcChatService {
  const SupabaseArcChatService({
    required this.client,
    this.fallback = const LocalArcChatService(),
  });

  final SupabaseClient client;
  final ArcChatService fallback;

  @override
  Future<ArcChatResponse> send({
    required String userMessage,
    required List<ArcChatMessage> history,
    required ArcChatContext context,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return fallback.send(
        userMessage: userMessage,
        history: history,
        context: context,
      );
    }

    try {
      final response = await client.functions.invoke(
        'arc-chat',
        body: buildRequestBody(
          userMessage: userMessage,
          history: history,
          context: context,
        ),
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      return parseResponseData(
        data,
        sourceInput: userMessage,
        allowedQuestIds: context.activeQuests.map((quest) => quest.id).toSet(),
        allowedMissionIds: context.recentMissions
            .map((mission) => mission.id)
            .toSet(),
      );
    } catch (_) {
      return fallback.send(
        userMessage: userMessage,
        history: history,
        context: context,
      );
    }
  }

  static const _fallbackMessage = '今はうまく答えをまとめられなかった。もう一度、短く聞かせてくれる？';

  static ArcChatResponse parseResponseData(
    Map<String, dynamic> data, {
    required String sourceInput,
    Set<String> allowedQuestIds = const {},
    Set<String> allowedMissionIds = const {},
  }) {
    final suggestionData = data['quest_suggestion'];
    final suggestion = suggestionData is Map
        ? _suggestionFromData(
            Map<String, dynamic>.from(suggestionData),
            sourceInput: sourceInput,
          )
        : inferArcQuestSuggestion(sourceInput);
    final clarificationQuestions = suggestion == null
        ? const <QuestClarificationQuestion>[]
        : QuestClarificationService.resolve(
            input: suggestion.sourceInput,
            category: suggestion.category,
            targetDate: null,
          );
    return ArcChatResponse(
      message: data['message'] as String? ?? _fallbackMessage,
      sourceType: data['source_type'] as String? ?? 'arc_chat',
      quickActions:
          (data['quick_actions'] as List?)?.whereType<String>().toList() ??
          const [],
      questSuggestion: suggestion,
      clarificationQuestions: clarificationQuestions,
      questChanges: _questChangesFromData(
        data,
        allowedQuestIds: allowedQuestIds,
        allowedMissionIds: allowedMissionIds,
      ),
    );
  }

  static List<ArcQuestChangeProposal> _questChangesFromData(
    Map<String, dynamic> data, {
    required Set<String> allowedQuestIds,
    required Set<String> allowedMissionIds,
  }) {
    final sources =
        (data['grounding_sources'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map(_groundingSourceFromData)
            .whereType<ArcGroundingSource>()
            .take(6)
            .toList(growable: false) ??
        const <ArcGroundingSource>[];
    final values = data['quest_changes'];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) {
          final kind = arcQuestChangeKindFromStorage(item['kind'] as String?);
          final questId = (item['quest_id'] as String?)?.trim() ?? '';
          final targetMissionId = (item['target_mission_id'] as String?)
              ?.trim();
          if (kind == null ||
              questId.isEmpty ||
              (allowedQuestIds.isNotEmpty &&
                  !allowedQuestIds.contains(questId)) ||
              (targetMissionId?.isNotEmpty == true &&
                  allowedMissionIds.isNotEmpty &&
                  !allowedMissionIds.contains(targetMissionId))) {
            return null;
          }
          final title = (item['title'] as String?)?.trim() ?? '';
          if (title.isEmpty) return null;
          return ArcQuestChangeProposal(
            id: _limitText(
              (item['id'] as String?)?.trim().isNotEmpty == true
                  ? (item['id'] as String).trim()
                  : '${kind.name}-$questId-$title',
              limit: 160,
            ),
            kind: kind,
            questId: questId,
            targetMissionId: targetMissionId?.isEmpty == true
                ? null
                : targetMissionId,
            title: _limitText(title, limit: InputLimits.missionTitle),
            description: _limitText(
              (item['description'] as String?)?.trim() ?? '',
              limit: InputLimits.missionDescription,
            ),
            rationale: _limitText(
              (item['rationale'] as String?)?.trim() ?? '',
              limit: 280,
            ),
            referenceQuery: _optionalLimitedText(
              item['reference_query'],
              InputLimits.missionDescription,
            ),
            proposedTargetDate: DateTime.tryParse(
              (item['proposed_target_date'] as String?) ?? '',
            ),
            groundingSources: sources,
          );
        })
        .whereType<ArcQuestChangeProposal>()
        .take(3)
        .toList(growable: false);
  }

  static ArcGroundingSource? _groundingSourceFromData(
    Map<String, dynamic> data,
  ) {
    final uri = Uri.tryParse(data['url'] as String? ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return ArcGroundingSource(
      title: _limitText(data['title'] as String? ?? uri.host, limit: 180),
      publisher: _limitText(
        data['publisher'] as String? ?? uri.host,
        limit: 120,
      ),
      url: uri,
    );
  }

  static String? _optionalLimitedText(Object? value, int limit) {
    if (value is! String || value.trim().isEmpty) return null;
    return _limitText(value.trim(), limit: limit);
  }

  static ArcQuestSuggestion? _suggestionFromData(
    Map<String, dynamic> data, {
    required String sourceInput,
  }) {
    final title = (data['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return inferArcQuestSuggestion(sourceInput);
    final difficultyValue = data['difficulty'] as String?;
    return ArcQuestSuggestion(
      title: _limitText(title, limit: InputLimits.questTitle),
      description: _limitText(
        (data['description'] as String?)?.trim().isNotEmpty == true
            ? (data['description'] as String).trim()
            : sourceInput.trim(),
        limit: InputLimits.questDescription,
      ),
      category: _limitText(
        (data['category'] as String?)?.trim().isNotEmpty == true
            ? (data['category'] as String).trim()
            : '冒険',
        limit: InputLimits.category,
      ),
      difficulty: QuestDifficulty.values.firstWhere(
        (value) => value.storageKey == difficultyValue,
        orElse: () => QuestDifficulty.normal,
      ),
      sourceInput: sourceInput.trim(),
      motivation: _limitText(
        (data['motivation'] as String?)?.trim() ?? '',
        limit: InputLimits.questDescription,
      ),
      successCondition: _limitText(
        (data['success_condition'] as String?)?.trim() ?? '',
        limit: InputLimits.questDescription,
      ),
      realityFrame: (data['reality_frame'] as String?) ?? 'uncertain',
      reframedOutcome: (data['reframed_outcome'] as String?)?.trim(),
    );
  }

  static Map<String, Object?> buildRequestBody({
    required String userMessage,
    required List<ArcChatMessage> history,
    required ArcChatContext context,
  }) {
    return {
      'message': _limitText(
        userMessage.trim(),
        limit: InputLimits.arcChatMessage,
      ),
      'history': history
          .take(QuestraPerformanceLimits.arcChatHistoryContextLimit)
          .map(
            (message) => {
              'role': message.fromArc ? 'arc' : 'user',
              'text': _limitText(message.text),
            },
          )
          .toList(growable: false),
      'context': {
        'active_quests': context.activeQuests
            .take(QuestraPerformanceLimits.arcChatActiveQuestContextLimit)
            .map(
              (quest) => {
                'id': quest.id,
                'title': _limitText(quest.title),
                'description': _limitText(quest.description),
                'progress': quest.progress,
                'category': _limitText(quest.category),
              },
            )
            .toList(growable: false),
        'recent_missions': context.recentMissions
            .take(QuestraPerformanceLimits.arcChatRecentMissionContextLimit)
            .map(
              (mission) => {
                'id': mission.id,
                'quest_id': mission.questId,
                'title': _limitText(mission.title),
                'description': _limitText(mission.description),
                'status': mission.status.storageKey,
                'sort_order': mission.sortOrder,
              },
            )
            .toList(growable: false),
        'recent_tasks': context.recentTasks
            .where((task) => task.isOpen)
            .take(QuestraPerformanceLimits.arcChatRecentTaskContextLimit)
            .map(
              (task) => {
                'id': task.id,
                'quest_id': task.questId,
                'mission_id': task.missionId,
                'title': _limitText(task.title),
                'action': _limitText(task.action),
                'done_condition': _limitText(task.doneCondition),
                'status': task.status.storageKey,
                'dependency_ids': task.dependencyIds.take(8).toList(),
              },
            )
            .toList(growable: false),
        'recent_trails': context.recentTrails
            .take(QuestraPerformanceLimits.arcChatRecentTrailContextLimit)
            .map(
              (trail) => {
                'id': trail.id,
                'quest_id': trail.questId,
                'mission_id': trail.missionId,
                'title': _limitText(trail.title),
                'summary': _limitText(trail.summary),
                'trail_type': trail.trailType.storageKey,
              },
            )
            .toList(growable: false),
        'memories': context.memories
            .take(QuestraPerformanceLimits.arcChatMemoryContextLimit)
            .map(
              (memory) => {
                'id': memory.id,
                'title': _limitText(memory.title),
                'content': _limitText(memory.content),
                'importance_score': memory.importanceScore,
                'memory_type': memory.memoryType.storageKey,
              },
            )
            .toList(growable: false),
      },
    };
  }

  static String _limitText(
    String value, {
    int limit = QuestraPerformanceLimits.arcChatContextTextLimit,
  }) {
    if (value.length <= limit) {
      return value;
    }
    return value.substring(0, limit);
  }
}

ArcQuestSuggestion? inferArcQuestSuggestion(String rawInput) {
  final input = rawInput.trim();
  if (input.isEmpty || !_looksLikeQuestIntent(input)) return null;
  final title = _questTitleFromInput(input);
  return ArcQuestSuggestion(
    title: title.length <= InputLimits.questTitle
        ? title
        : title.substring(0, InputLimits.questTitle),
    description: input.length <= InputLimits.questDescription
        ? input
        : input.substring(0, InputLimits.questDescription),
    category: _categoryFromInput(input),
    difficulty: QuestDifficulty.normal,
    sourceInput: input,
  );
}

bool _looksLikeQuestIntent(String input) {
  return RegExp(r'(たい|目指したい|挑戦したい|実現したい|できるようになりたい|始めたい|叶えたい)').hasMatch(input);
}

String _questTitleFromInput(String input) {
  final firstSentence = input.split(RegExp(r'[\n。！？!?]')).first.trim();
  return firstSentence
      .replaceFirst(RegExp(r'に行きたい$'), 'へ行く')
      .replaceFirst(RegExp(r'を始めたい$'), 'を始める')
      .replaceFirst(RegExp(r'できるようになりたい$'), 'できるようになる')
      .replaceFirst(RegExp(r'になりたい$'), 'になる')
      .replaceFirst(RegExp(r'したい$'), 'する');
}

String _categoryFromInput(String input) {
  if (RegExp(r'(旅行|旅|海外|行きたい|登山|キャンプ)').hasMatch(input)) return '旅行';
  if (RegExp(r'(英語|勉強|学習|資格|読書)').hasMatch(input)) return '学習';
  if (RegExp(r'(健康|運動|筋トレ|走|ダイエット)').hasMatch(input)) return '健康';
  if (RegExp(r'(仕事|起業|サービス|転職|事業)').hasMatch(input)) return '仕事';
  return '冒険';
}

List<ArcQuestChangeProposal> _inferLocalQuestChanges(
  String rawInput,
  ArcChatContext context,
) {
  if (context.activeQuests.isEmpty) return const [];
  final input = rawInput.trim();
  if (!RegExp(r'(どんな|どう|必要|おすすめ|苦手|比較|教え|？|\?)').hasMatch(input)) {
    return const [];
  }
  final quest = context.activeQuests.first;
  final missionTitle = switch (input) {
    final value when RegExp(r'登山靴|トレッキングシューズ').hasMatch(value) => '登山靴の条件を比較する',
    final value
        when RegExp(r'Part\s*7', caseSensitive: false).hasMatch(value) =>
      'Part 7を1セット解く',
    final value
        when RegExp(r'LinkedIn', caseSensitive: false).hasMatch(value) =>
      'LinkedInプロフィールを整える',
    _ => '${input.split(RegExp(r'[。！？!?\n]')).first.takeCharacters(28)}を確認する',
  };
  final existing = context.recentMissions.where(
    (mission) =>
        mission.questId == quest.id &&
        _sharesTopic(mission.title, missionTitle),
  );
  if (existing.isNotEmpty) {
    final mission = existing.first;
    return [
      ArcQuestChangeProposal(
        id: 'local-reference-${mission.id}',
        kind: ArcQuestChangeKind.addReference,
        questId: quest.id,
        targetMissionId: mission.id,
        title: '「${mission.title}」に参考情報を追加',
        description: '今の相談を、Missionの実行サポートから検索できるようにします。',
        rationale: 'Questに関連する既存Missionがあります。',
        referenceQuery: input,
      ),
    ];
  }
  return [
    ArcQuestChangeProposal(
      id: 'local-mission-${quest.id}-${missionTitle.hashCode}',
      kind: ArcQuestChangeKind.addMission,
      questId: quest.id,
      title: missionTitle,
      description: '必要条件と選択肢を比較し、次の行動を1つ決めたら完了です。',
      rationale: '今の相談は「${quest.title}」を進める具体的な一歩にできます。',
      referenceQuery: input,
    ),
  ];
}

bool _sharesTopic(String existing, String proposed) {
  final normalizedExisting = existing.toLowerCase().replaceAll(' ', '');
  final normalizedProposed = proposed.toLowerCase().replaceAll(' ', '');
  return normalizedExisting.contains(normalizedProposed) ||
      normalizedProposed.contains(normalizedExisting) ||
      (normalizedExisting.contains('登山靴') &&
          normalizedProposed.contains('登山靴')) ||
      (normalizedExisting.contains('part7') &&
          normalizedProposed.contains('part7')) ||
      (normalizedExisting.contains('linkedin') &&
          normalizedProposed.contains('linkedin'));
}

extension on String {
  String takeCharacters(int count) {
    if (length <= count) return this;
    return substring(0, count);
  }
}
