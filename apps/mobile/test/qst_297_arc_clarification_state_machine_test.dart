import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_chat_service.dart';
import 'package:questra/features/arc/arc_quest_clarification_session.dart';
import 'package:questra/features/quest/quest_clarification_service.dart';

void main() {
  test(
    'ambiguous travel wish stays clarifying until all answers exist',
    () async {
      final response = await const LocalArcChatService().send(
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
      expect(response.clarificationQuestions, hasLength(3));
      var session = ArcQuestClarificationSession(
        suggestion: response.questSuggestion!,
        questions: response.clarificationQuestions,
      );
      expect(session.isComplete, isFalse);
      expect(session.currentQuestion?.type, QuestClarificationType.deadline);

      session = session.answer('2027年3月');
      expect(session.isComplete, isFalse);
      expect(session.currentQuestion?.type, QuestClarificationType.party);
      session = session.answer('家族と');
      expect(session.currentQuestion?.type, QuestClarificationType.budget);
      session = session.answer('30万円まで');
      expect(session.isComplete, isTrue);
      expect(session.resolvedSuggestion.sourceInput, 'シンガポールに行きたい');
      expect(session.resolvedSuggestion.title, 'シンガポールへ行く');
      expect(session.resolvedSuggestion.description, isNot(contains('航路条件')));
      expect(session.resolvedSuggestion.confirmedAnswers, {
        QuestClarificationType.deadline: '2027年3月',
        QuestClarificationType.party: '家族と',
        QuestClarificationType.budget: '30万円まで',
      });
    },
  );

  test('clear dated outcome is immediately confirmable', () async {
    final response = await const LocalArcChatService().send(
      userMessage: '2027年3月までにシンガポールへ行きたい',
      history: const [],
      context: const ArcChatContext(
        activeQuests: [],
        recentMissions: [],
        recentTrails: [],
        memories: [],
      ),
    );

    expect(response.questSuggestion, isNotNull);
    expect(response.clarificationQuestions, isEmpty);
  });

  test(
    'Arc screen suppresses confirmation and quick actions while clarifying',
    () {
      final source = File(
        'lib/features/arc/arc_screen.dart',
      ).readAsStringSync();

      expect(source, contains('if (_clarificationSession == null)'));
      expect(source, contains('_pendingQuestSuggestion = null'));
      expect(source, contains('Questを整理中'));
      expect(source, contains('next.isComplete'));
    },
  );
}
