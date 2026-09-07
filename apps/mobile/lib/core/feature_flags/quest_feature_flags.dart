class QuestFeatureFlags {
  const QuestFeatureFlags();

  bool get compactHeaderEnabled =>
      const bool.fromEnvironment('QUEST_COMPACT_HEADER_V2', defaultValue: true);
}
