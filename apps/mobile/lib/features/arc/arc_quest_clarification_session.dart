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
    final lines = <String>[];
    for (final question in questions) {
      final answer = answers[question.type]?.trim();
      if (answer == null || answer.isEmpty) continue;
      lines.add('${question.label} $answer');
    }
    if (lines.isEmpty) return suggestion;
    final context = lines.map((line) => '- $line').join('\n');
    return ArcQuestSuggestion(
      title: suggestion.title,
      description: '${suggestion.description.trim()}\n\n航路条件:\n$context',
      category: suggestion.category,
      difficulty: suggestion.difficulty,
      sourceInput: '${suggestion.sourceInput.trim()}\n$context',
      motivation: suggestion.motivation,
      successCondition: suggestion.successCondition,
      realityFrame: suggestion.realityFrame,
      reframedOutcome: suggestion.reframedOutcome,
    );
  }
}
