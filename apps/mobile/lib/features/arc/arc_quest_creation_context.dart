import 'arc_chat_service.dart';
import 'arc_quick_action.dart';

class ArcQuestCreationContext {
  const ArcQuestCreationContext({this.suggestion, this.wish = ''});

  final ArcQuestSuggestion? suggestion;
  final String wish;

  static ArcQuestCreationContext fromConversation({
    required Iterable<ArcChatMessage> messages,
    required Iterable<ArcQuestSuggestion?> suggestions,
  }) {
    for (final suggestion in suggestions) {
      if (suggestion != null &&
          suggestion.sourceInput.trim().isNotEmpty &&
          !isArcActionPrompt(suggestion.sourceInput)) {
        return ArcQuestCreationContext(
          suggestion: suggestion,
          wish: suggestion.sourceInput,
        );
      }
    }
    // Do not concatenate the transcript: short clarification answers are not titles.
    for (final message in messages.toList().reversed) {
      if (!message.fromArc &&
          !isArcActionPrompt(message.text) &&
          inferArcQuestSuggestion(message.text) != null) {
        return ArcQuestCreationContext(wish: message.text);
      }
    }
    return const ArcQuestCreationContext();
  }
}
