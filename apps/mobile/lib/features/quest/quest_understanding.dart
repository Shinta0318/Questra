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

  static QuestUnderstanding? fromJson(Object? value) {
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);
    final originalWish = data['original_wish'] as String?;
    final questOutcome = data['quest_outcome'] as String?;
    final successEvidence = data['success_evidence'] as String?;
    if (originalWish == null ||
        questOutcome == null ||
        successEvidence == null) {
      return null;
    }
    return QuestUnderstanding(
      originalWish: originalWish,
      questOutcome: questOutcome,
      successEvidence: successEvidence,
      motivation: data['motivation'] as String? ?? '',
      currentState: data['current_state'] as String? ?? '',
      constraints: _strings(data['constraints']),
      knownResources: _strings(data['known_resources']),
      unknowns: _strings(data['unknowns']),
      planningRisks: _strings(data['planning_risks']),
      planningMode: QuestPlanningMode.values.firstWhere(
        (mode) => mode.name == data['planning_mode'],
        orElse: () => QuestPlanningMode.project,
      ),
      assumptions: _strings(data['assumptions']),
      version: data['version'] as int? ?? 1,
      evaluatedAt: DateTime.tryParse(data['evaluated_at'] as String? ?? ''),
    );
  }

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

  static List<String> _strings(Object? value) =>
      (value as List?)?.whereType<String>().toList(growable: false) ?? const [];
}
