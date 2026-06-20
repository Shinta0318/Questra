import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_chat_service.dart';
import 'package:questra/features/quest/quest_model.dart';
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
}
