import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  test('local guide never replaces Gemini with fixed Missions', () async {
    const service = LocalArcQuestGuideService();
    final quest = Quest(
      title: 'シンガポールへ行く',
      description: '家族と食文化を楽しむ。予算は30万円。',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      category: '旅行',
    );

    await expectLater(
      service.generate(quest: quest),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('Gemini Planning API'), contains('入力内容は保持')),
        ),
      ),
    );
  });
}
