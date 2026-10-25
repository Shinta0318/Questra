import '../quest/quest_clarification_service.dart';
import 'arc_chat_service.dart';

class ArcQuestClarificationSession {
  const ArcQuestClarificationSession({
    required this.suggestion,
    required this.questions,
    this.answers = const {},
  }) : assert(questions.length <= 3);

  final ArcQuestSuggestion suggestion;
  final List<QuestClarificationQuestion> questions;
  final Map<QuestClarificationType, String> answers;

  int get answeredCount => answers.length;
  bool get isComplete => answeredCount >= questions.length;

  QuestClarificationQuestion? get currentQuestion {
    for (final question in questions) {
      if (!answers.containsKey(question.type)) return question;
    }
    return null;
  }

  ArcQuestClarificationSession answer(String value) {
    final question = currentQuestion;
    final answer = value.trim();
    if (question == null || answer.isEmpty) return this;
    return ArcQuestClarificationSession(
      suggestion: suggestion,
      questions: questions,
      answers: {...answers, question.type: answer},
    );
  }

  ArcQuestSuggestion get resolvedSuggestion {
    if (answers.isEmpty) return suggestion;
    return ArcQuestSuggestion(
      title: suggestion.title,
      description: suggestion.description,
      category: suggestion.category,
      difficulty: suggestion.difficulty,
      sourceInput: suggestion.sourceInput.trim(),
      motivation: suggestion.motivation,
      successCondition: suggestion.successCondition,
      realityFrame: suggestion.realityFrame,
      reframedOutcome: suggestion.reframedOutcome,
      confirmedAnswers: {...suggestion.confirmedAnswers, ...answers},
    );
  }
}
