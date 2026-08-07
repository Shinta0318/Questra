enum QuestRealityFrame { achievable, uncertain, ambitious, symbolic }

class QuestIntentDraft {
  const QuestIntentDraft({
    required this.outcome,
    required this.motivation,
    required this.successCondition,
    required this.realityFrame,
    this.reframedOutcome,
  });

  final String outcome;
  final String motivation;
  final String successCondition;
  final QuestRealityFrame realityFrame;
  final String? reframedOutcome;

  String get effectiveOutcome => reframedOutcome ?? outcome;
}
