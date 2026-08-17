import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_clarification_service.dart';
import 'package:questra/features/quest/quest_intent_resolution_service.dart';

void main() {
  const service = LocalQuestIntentResolutionService();

  test('travel wish is understood without fabricated Quest variants', () async {
    final result = await service.resolve(wish: 'シンガポールへ行きたい');

    expect(result.questType, QuestType.travel);
    expect(result.directions, isEmpty);
    expect(result.clarificationQuestions.map((item) => item.type), [
      QuestClarificationType.deadline,
      QuestClarificationType.party,
      QuestClarificationType.budget,
      QuestClarificationType.travelActivity,
      QuestClarificationType.travelStyle,
    ]);
    expect(result.optimizedTitle, isNot(contains('習慣にする')));
    expect(result.optimizedTitle, isNot(contains('小さく試す')));
  });

  test('learning wish asks only questions that change its outcome', () async {
    final result = await service.resolve(wish: '英語を話せるようになりたい');

    expect(result.questType, QuestType.learning);
    expect(
      result.clarificationQuestions.map((item) => item.type),
      containsAll([
        QuestClarificationType.purpose,
        QuestClarificationType.targetLevel,
      ]),
    );
    expect(result.directions, isEmpty);
  });

  test('specific dated outcome skips unnecessary clarification', () async {
    final result = await service.resolve(wish: '2027年3月までにTOEIC700点を取る');

    expect(result.clarity, QuestIntentClarity.clear);
    expect(result.clarificationQuestions, isEmpty);
    expect(result.directions, isEmpty);
  });

  test('habit language is classified semantically', () async {
    final result = await service.resolve(wish: '毎朝走りたい');

    expect(result.questType, QuestType.habit);
    expect(
      result.clarificationQuestions.map((item) => item.type),
      isNot(contains(QuestClarificationType.party)),
    );
    expect(result.directions, isEmpty);
  });
}
