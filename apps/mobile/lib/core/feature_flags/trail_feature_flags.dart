class TrailFeatureFlags {
  const TrailFeatureFlags();

  bool get singleTimelineEnabled => const bool.fromEnvironment(
    'TRAIL_SINGLE_TIMELINE_V1',
    defaultValue: true,
  );
}
