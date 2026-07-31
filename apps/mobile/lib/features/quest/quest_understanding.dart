enum QuestPlanningMode { project, habit, exploration, preparation, challenge }

class QuestUnderstanding {
  QuestUnderstanding({
    required this.originalWish,
    required this.questOutcome,
    required this.successEvidence,
    required this.motivation,
    required this.currentState,
    required this.constraints,
    required this.knownResources,
    required this.unknowns,
    required this.planningRisks,
    required this.planningMode,
    required this.assumptions,
    this.version = 1,
    DateTime? evaluatedAt,
  }) : evaluatedAt = evaluatedAt ?? DateTime.now();

  final String originalWish;
  final String questOutcome;
  final String successEvidence;
  final String motivation;
  final String currentState;
  final List<String> constraints;
  final List<String> knownResources;
  final List<String> unknowns;
  final List<String> planningRisks;
  final QuestPlanningMode planningMode;
  final List<String> assumptions;
  final int version;
  final DateTime evaluatedAt;

  Map<String, dynamic> toJson() => {
    'original_wish': originalWish,
    'quest_outcome': questOutcome,
    'success_evidence': successEvidence,
    'motivation': motivation,
    'current_state': currentState,
    'constraints': constraints,
    'known_resources': knownResources,
    'unknowns': unknowns,
    'planning_risks': planningRisks,
    'planning_mode': planningMode.name,
    'assumptions': assumptions,
    'version': version,
    'evaluated_at': evaluatedAt.toIso8601String(),
  };
}
