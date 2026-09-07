class OnboardingTourFeatureFlags {
  const OnboardingTourFeatureFlags();

  /// Kill switch for the Settings replay entry point.
  ///
  /// Passing `--dart-define=TOUR_REPLAY_V2=false` keeps the current screen
  /// usable while the replay experience is rolled back.
  bool get replayV2Enabled =>
      const bool.fromEnvironment('TOUR_REPLAY_V2', defaultValue: true);
}
