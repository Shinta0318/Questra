class QuestJourneyFeatureFlags {
  const QuestJourneyFeatureFlags();

  /// Kill switch for staged rollout. Passing
  /// --dart-define=QUEST_JOURNEY_WORKSPACE=false restores the legacy detail.
  bool get workspaceEnabled => const bool.fromEnvironment(
        'QUEST_JOURNEY_WORKSPACE',
        defaultValue: true,
      );
}
