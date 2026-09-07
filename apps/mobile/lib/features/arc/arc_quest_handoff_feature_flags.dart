class ArcQuestHandoffFeatureFlags {
  const ArcQuestHandoffFeatureFlags();

  /// Kill switch for the retry/manual/later recovery panel.
  bool get recoveryV2Enabled => const bool.fromEnvironment(
    'QUEST_HANDOFF_RECOVERY_V2',
    defaultValue: true,
  );
}
