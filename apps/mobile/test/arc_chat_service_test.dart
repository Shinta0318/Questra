import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/performance/performance_limits.dart';
import 'package:questra/features/arc/arc_chat_service.dart';
import 'package:questra/features/arc_memory/arc_memory_model.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  test('local Arc chat response uses Quest and Trail context', () async {
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
    expect(response.quickActions, isNotEmpty);
    expect(response.sourceType, 'local_fallback');
  });

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
      ((memories.first as Map<String, Object?>)['content'] as String).length,
      QuestraPerformanceLimits.arcChatContextTextLimit,
    );
  });
}
