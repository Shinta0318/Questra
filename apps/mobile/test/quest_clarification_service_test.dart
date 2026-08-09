import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_clarification_service.dart';

void main() {
  test('travel asks only missing route-changing questions up to three', () {
    final questions = QuestClarificationService.resolve(
      input: 'シンガポールへ行きたい',
      category: '冒険',
      targetDate: null,
    );

    expect(questions, hasLength(3));
    expect(questions.map((question) => question.type), [
      QuestClarificationType.deadline,
      QuestClarificationType.party,
      QuestClarificationType.purpose,
    ]);
  });

  test('provided facts are not asked again', () {
    final questions = QuestClarificationService.resolve(
      input: '初心者で予算10万円。シンガポールへ行きたい',
      category: '旅行',
      targetDate: DateTime(2027, 4, 1),
    );

    expect(
      questions.map((question) => question.type),
      isNot(contains(QuestClarificationType.deadline)),
    );
    expect(
      questions.map((question) => question.type),
      isNot(contains(QuestClarificationType.location)),
    );
    expect(
      questions.map((question) => question.type),
      isNot(contains(QuestClarificationType.experience)),
    );
  });

  test('unknown wishes keep a short skippable discovery path', () {
    final questions = QuestClarificationService.resolve(
      input: 'いつか自分だけの新しい挑戦を形にしたい',
      category: 'その他',
      targetDate: null,
    );

    expect(questions, hasLength(2));
    expect(questions.map((question) => question.type), [
      QuestClarificationType.purpose,
      QuestClarificationType.deadline,
    ]);
  });

  test('only answered context is appended for planning', () {
    final description = QuestClarificationService.appendAnsweredContext(
      description: 'シンガポールへ行きたい',
      targetDate: DateTime(2027, 4, 1),
      answers: const {
        QuestClarificationType.budget: '20万円まで',
        QuestClarificationType.experience: '',
      },
    );

    expect(description, contains('期限: 2027年4月1日'));
    expect(description, contains('予算: 20万円まで'));
    expect(description, isNot(contains('現在地:')));
  });
}
