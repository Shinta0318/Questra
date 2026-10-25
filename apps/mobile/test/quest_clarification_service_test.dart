import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_clarification_service.dart';
import 'package:questra/features/quest/quest_understanding.dart';

void main() {
  test('travel asks at most three route-changing questions', () {
    final questions = QuestClarificationService.resolve(
      input: 'シンガポールへ行きたい',
      category: '冒険',
      targetDate: null,
    );

    expect(questions, hasLength(3));
    expect(questions.map((question) => question.type), [
      QuestClarificationType.deadline,
      QuestClarificationType.party,
      QuestClarificationType.budget,
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
    expect(
      questions.map((question) => question.type),
      isNot(contains(QuestClarificationType.budget)),
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
        QuestClarificationType.travelActivity: '食文化と現地交流',
        QuestClarificationType.travelStyle: 'ゆったり食文化を楽しむ',
        QuestClarificationType.experience: '',
      },
    );

    expect(description, contains('希望時期: 2027年4月'));
    expect(description, contains('予算: 20万円まで'));
    expect(description, contains('重視するアクティビティ・体験: 食文化と現地交流'));
    expect(description, contains('旅行スタイル: ゆったり食文化を楽しむ'));
    expect(description, isNot(contains('現在地:')));
  });

  test('non-travel wishes do not receive travel-only questions', () {
    final questions = QuestClarificationService.resolve(
      input: '英語を話せるようになりたい',
      category: '学習',
      targetDate: null,
    );

    expect(
      questions.map((question) => question.type),
      isNot(contains(QuestClarificationType.travelStyle)),
    );
    expect(
      questions.map((question) => question.type),
      isNot(contains(QuestClarificationType.party)),
    );
  });

  test('known dated outcome needs no follow-up question', () {
    final questions = QuestClarificationService.resolve(
      input: '2027年3月までにシンガポールへ行きたい',
      category: '旅行',
      targetDate: DateTime(2027, 3),
    );
    expect(questions, isEmpty);
  });

  test('existing context is not appended twice', () {
    const existing = 'シンガポールへ行く\n\n航路条件:\n- 同行者: 家族と';
    expect(
      QuestClarificationService.appendAnsweredContext(
        description: existing,
        targetDate: null,
        answers: const {QuestClarificationType.party: '家族と'},
      ),
      existing,
    );
  });

  test('confirmed context survives the existing Quest understanding JSON', () {
    final understanding = QuestUnderstanding(
      originalWish: 'シンガポールへ行きたい',
      questOutcome: 'シンガポールへ行く',
      successEvidence: '',
      motivation: '',
      currentState: '',
      constraints: const [],
      knownResources: const [],
      unknowns: const [],
      planningRisks: const [],
      planningMode: QuestPlanningMode.project,
      assumptions: const [],
      confirmedConditions: {
        QuestClarificationType.party: QuestConfirmedCondition(
          value: '家族と',
          source: QuestConditionSource.userConfirmed,
          confirmedAt: DateTime.utc(2026, 9, 30),
        ),
      },
    );
    final restored = QuestUnderstanding.fromJson(understanding.toJson())!;
    expect(
      restored.confirmedConditions[QuestClarificationType.party]?.value,
      '家族と',
    );
    expect(
      restored.confirmedConditions[QuestClarificationType.party]?.source,
      QuestConditionSource.userConfirmed,
    );
    expect(
      QuestUnderstanding.fromJson({
        ...understanding.toJson(),
        'confirmed_conditions': null,
      })?.confirmedConditions,
      isEmpty,
    );
  });

  test('typed context is shown once without dropping following prose', () {
    const source = '旅行したい\n\n航路条件:\n- 同行者: 家族と\n- 予算: 30万円\n叶えたい理由: 家族の思い出';
    expect(
      QuestClarificationService.descriptionWithoutAnsweredContext(source),
      '旅行したい\n\n叶えたい理由: 家族の思い出',
    );
  });
}
