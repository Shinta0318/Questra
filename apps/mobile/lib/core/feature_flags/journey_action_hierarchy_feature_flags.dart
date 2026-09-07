class JourneyActionHierarchyFeatureFlags {
  const JourneyActionHierarchyFeatureFlags();

  bool get enabled => const bool.fromEnvironment(
    'JOURNEY_ACTION_HIERARCHY_V2',
    defaultValue: true,
  );
}
