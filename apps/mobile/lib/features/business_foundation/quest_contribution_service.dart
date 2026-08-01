enum SupportInteractionType {
  viewed,
  saved,
  adopted,
  dismissed,
  accepted,
  reported,
  actionStarted,
  actionCompleted,
  refunded,
}

class SupportInteraction {
  const SupportInteraction({
    required this.id,
    required this.questId,
    required this.missionId,
    required this.sourceType,
    required this.type,
    required this.occurredAt,
    required this.consentVersion,
  });
  final String id;
  final String questId;
  final String missionId;
  final String sourceType;
  final SupportInteractionType type;
  final DateTime occurredAt;
  final int? consentVersion;
}

class QuestContributionService {
  const QuestContributionService();
  bool isMeaningfulInteraction(SupportInteraction interaction) =>
      interaction.type != SupportInteractionType.viewed &&
      interaction.type != SupportInteractionType.dismissed;
  bool mayMeasureBusinessContribution({
    required SupportInteraction interaction,
    required bool consentGranted,
    required bool sensitive,
  }) =>
      interaction.sourceType == 'business' &&
      consentGranted &&
      !sensitive &&
      isMeaningfulInteraction(interaction);
  double associationConfidence({
    required bool missionCompleted,
    required bool userMarkedHelpful,
  }) => !missionCompleted
      ? 0
      : userMarkedHelpful
      ? 0.7
      : 0.35;
}
