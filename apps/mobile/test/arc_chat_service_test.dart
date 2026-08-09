import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/performance/performance_limits.dart';
import 'package:questra/core/validation/input_validators.dart';
import 'package:questra/features/arc/arc_chat_service.dart';
import 'package:questra/features/arc/arc_quest_change_proposal.dart';
import 'package:questra/features/arc_memory/arc_memory_model.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  test('local Arc chat response uses Quest and Trail context', () async {
    const service = LocalArcChatService();
    final response = await service.send(
      userMessage: '次の一歩を相談したいです',
      history: const [],
      context: ArcChatContext(
        activeQuests: [
          Quest(
            title: 'Questraをローンチする',
            description: 'Betaへ進める',
            difficulty: QuestDifficulty.normal,
            status: QuestStatus.active,
            visibility: QuestVisibility.private,
          ),
        ],
        recentMissions: const [],
        recentTrails: [
          Trail(
            title: 'LPを見直した',
            summary: '改善点を整理した',
            content: '次の一歩が見えた',
            trailType: TrailType.questRecord,
          ),
        ],
        memories: const [],
      ),
    );

    expect(response.message, contains('Questraをローンチする'));
    expect(response.message, contains('LPを見直した'));
    expect(response.message, isNot(contains('おかえり、キャプテン')));
    expect(response.message, isNot(contains('気持ちを受け取った')));
    expect('?'.allMatches(response.message).length, lessThanOrEqualTo(1));
    expect(response.quickActions, isNotEmpty);
    expect(response.sourceType, 'local_fallback');
  });

  test(
    'local Arc chat prioritizes a current concern over journey history',
    () async {
      const service = LocalArcChatService();
      final response = await service.send(
        userMessage: '今日は少し不安です',
        history: const [],
        context: ArcChatContext(
          activeQuests: [
            Quest(
              title: 'Questraをローンチする',
              description: 'Betaへ進める',
              difficulty: QuestDifficulty.normal,
              status: QuestStatus.active,
              visibility: QuestVisibility.private,
            ),
          ],
          recentMissions: const [],
          recentTrails: [
            Trail(
              title: '入力画面を見直した',
              summary: '改善点を整理した',
              content: '次の一歩が見えた',
              trailType: TrailType.questRecord,
            ),
          ],
          memories: const [],
        ),
      );

      expect(response.message, contains('気がかり'));
      expect(response.message, isNot(contains('Questraをローンチする')));
      expect(RegExp(r'[？?]').allMatches(response.message), hasLength(1));
    },
  );

  test('Supabase Arc chat payload keeps context within bounded limits', () {
    final longText = '航路'.padRight(
      QuestraPerformanceLimits.arcChatContextTextLimit + 40,
      'a',
    );
    final context = ArcChatContext(
      activeQuests: List.generate(
        QuestraPerformanceLimits.arcChatActiveQuestContextLimit + 2,
        (index) => Quest(
          title: 'Quest $index',
          description: longText,
          difficulty: QuestDifficulty.normal,
          status: QuestStatus.active,
          visibility: QuestVisibility.private,
        ),
      ),
      recentMissions: List.generate(
        QuestraPerformanceLimits.arcChatRecentMissionContextLimit + 2,
        (index) => Mission(
          questId: 'quest-$index',
          questTitle: 'Quest $index',
          title: 'Mission $index',
          description: 'Description $index',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
          status: MissionStatus.todo,
        ),
      ),
      recentTasks: List.generate(
        QuestraPerformanceLimits.arcChatRecentTaskContextLimit + 2,
        (index) => QuestraTask(
          id: 'task-$index',
          questId: 'quest-0',
          missionId: 'mission-0',
          title: 'Task $index',
          action: longText,
          doneCondition: '完了条件 $index',
          status: TaskStatus.ready,
        ),
      ),
      recentTrails: List.generate(
        QuestraPerformanceLimits.arcChatRecentTrailContextLimit + 2,
        (index) => Trail(
          title: 'Trail $index',
          summary: longText,
          content: 'Content $index',
          trailType: TrailType.questRecord,
        ),
      ),
      memories: List.generate(
        QuestraPerformanceLimits.arcChatMemoryContextLimit + 2,
        (index) => ArcMemory(
          userId: 'user-1',
          memoryType: ArcMemoryType.arcRelationshipMemory,
          title: 'Memory $index',
          content: longText,
          importanceScore: 0.8,
          emotionalTone: EmotionalTone.supportive,
          sourceType: ArcMemorySourceType.arcChat,
        ),
      ),
    );

    final body = SupabaseArcChatService.buildRequestBody(
      userMessage: '次の一歩を相談したい',
      history: List.generate(
        QuestraPerformanceLimits.arcChatHistoryContextLimit + 2,
        (index) => ArcChatMessage(
          text: longText,
          fromArc: index.isEven,
          createdAt: DateTime(2026, 6, 21),
        ),
      ),
      context: context,
    );

    final history = body['history'] as List<Object?>;
    final payloadContext = body['context'] as Map<String, Object?>;
    final activeQuests = payloadContext['active_quests'] as List<Object?>;
    final recentMissions = payloadContext['recent_missions'] as List<Object?>;
    final recentTasks = payloadContext['recent_tasks'] as List<Object?>;
    final recentTrails = payloadContext['recent_trails'] as List<Object?>;
    final memories = payloadContext['memories'] as List<Object?>;

    expect(
      history,
      hasLength(QuestraPerformanceLimits.arcChatHistoryContextLimit),
    );
    expect(
      activeQuests,
      hasLength(QuestraPerformanceLimits.arcChatActiveQuestContextLimit),
    );
    expect(
      recentMissions,
      hasLength(QuestraPerformanceLimits.arcChatRecentMissionContextLimit),
    );
    expect(
      recentTasks,
      hasLength(QuestraPerformanceLimits.arcChatRecentTaskContextLimit),
    );
    expect(
      recentTrails,
      hasLength(QuestraPerformanceLimits.arcChatRecentTrailContextLimit),
    );
    expect(
      memories,
      hasLength(QuestraPerformanceLimits.arcChatMemoryContextLimit),
    );
    expect(
      ((history.first as Map<String, Object?>)['text'] as String).length,
      QuestraPerformanceLimits.arcChatContextTextLimit,
    );
    expect(
      ((activeQuests.first as Map<String, Object?>)['description'] as String)
          .length,
      QuestraPerformanceLimits.arcChatContextTextLimit,
    );
    expect(
      ((recentTrails.first as Map<String, Object?>)['summary'] as String)
          .length,
      QuestraPerformanceLimits.arcChatContextTextLimit,
    );
    expect(
      ((recentTasks.first as Map<String, Object?>)['action'] as String).length,
      QuestraPerformanceLimits.arcChatContextTextLimit,
    );
    expect(
      ((memories.first as Map<String, Object?>)['content'] as String).length,
      QuestraPerformanceLimits.arcChatContextTextLimit,
    );
  });

  test('Supabase Arc chat payload trims and caps the user message', () {
    final body = SupabaseArcChatService.buildRequestBody(
      userMessage: '  ${'星' * (InputLimits.arcChatMessage + 20)}  ',
      history: const [],
      context: const ArcChatContext(
        activeQuests: [],
        recentMissions: [],
        recentTrails: [],
        memories: [],
      ),
    );

    expect((body['message'] as String).length, InputLimits.arcChatMessage);
  });

  test('travel wish becomes an editable Quest suggestion', () async {
    const service = LocalArcChatService();
    final response = await service.send(
      userMessage: 'シンガポールに行きたい',
      history: const [],
      context: const ArcChatContext(
        activeQuests: [],
        recentMissions: [],
        recentTrails: [],
        memories: [],
      ),
    );

    expect(response.questSuggestion, isNotNull);
    expect(response.questSuggestion!.title, 'シンガポールへ行く');
    expect(response.questSuggestion!.category, '旅行');
    expect(response.questSuggestion!.sourceInput, 'シンガポールに行きたい');
    expect(response.message, contains('シンガポールへ行く'));
    expect(response.message, endsWith('？'));
  });

  test('structured Gemini response preserves Quest planning fields', () {
    final response = SupabaseArcChatService.parseResponseData({
      'message': 'シンガポールへ向かう星図を描いてみよう。',
      'source_type': 'gemini_interactions',
      'quick_actions': ['旅程を考える'],
      'quest_suggestion': {
        'title': 'シンガポールを訪れる',
        'description': '文化と食を楽しむ旅を実現する',
        'category': '旅行',
        'difficulty': 'normal',
      },
    }, sourceInput: 'シンガポールに行きたい');

    expect(response.sourceType, 'gemini_interactions');
    expect(response.questSuggestion!.title, 'シンガポールを訪れる');
    expect(response.questSuggestion!.difficulty, QuestDifficulty.normal);
  });

  test('ordinary reflection does not force a Quest suggestion', () {
    expect(inferArcQuestSuggestion('今日は少し疲れた'), isNull);
  });

  test(
    'active Quest question becomes an approvable Mission proposal',
    () async {
      const service = LocalArcChatService();
      final response = await service.send(
        userMessage: '登山靴ってどんなのがいい？',
        history: const [],
        context: ArcChatContext(
          activeQuests: [
            Quest(
              id: 'quest-fuji',
              title: '富士山に登る',
              description: '',
              difficulty: QuestDifficulty.normal,
              status: QuestStatus.active,
              visibility: QuestVisibility.private,
            ),
          ],
          recentMissions: const [],
          recentTrails: const [],
          memories: const [],
        ),
      );

      expect(response.questChanges, hasLength(1));
      expect(response.questChanges.first.questId, 'quest-fuji');
      expect(response.questChanges.first.kind, ArcQuestChangeKind.addMission);
      expect(response.questChanges.first.title, contains('登山靴'));
      expect(response.questChanges.first.canApplyDirectly, isTrue);
    },
  );

  test(
    'structured Quest changes reject foreign IDs and unsafe source URLs',
    () {
      final response = SupabaseArcChatService.parseResponseData(
        {
          'message': 'この情報をMissionに反映できるよ。',
          'quest_changes': [
            {
              'id': 'valid',
              'kind': 'add_reference',
              'quest_id': 'quest-1',
              'target_mission_id': 'mission-1',
              'title': '公式ガイドを参考に追加',
              'description': '最新条件を確認する',
              'rationale': 'Missionに関連するため',
            },
            {
              'id': 'foreign',
              'kind': 'delete_mission',
              'quest_id': 'quest-other',
              'target_mission_id': 'mission-other',
              'title': '削除',
              'description': '',
              'rationale': '',
            },
          ],
          'grounding_sources': [
            {
              'title': 'Official',
              'publisher': 'Example',
              'url': 'https://example.com/guide',
            },
            {
              'title': 'Unsafe',
              'publisher': 'Local',
              'url': 'http://127.0.0.1/private',
            },
          ],
        },
        sourceInput: '最新情報を教えて',
        allowedQuestIds: const {'quest-1'},
        allowedMissionIds: const {'mission-1'},
      );

      expect(response.questChanges, hasLength(1));
      expect(response.questChanges.first.id, 'valid');
      expect(response.questChanges.first.groundingSources, hasLength(1));
      expect(
        response.questChanges.first.groundingSources.first.url.scheme,
        'https',
      );
    },
  );
}
