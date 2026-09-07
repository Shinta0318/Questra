class HomeFeatureFlags {
  const HomeFeatureFlags();

  bool get nextStepEnabled =>
      const bool.fromEnvironment('HOME_NEXT_STEP_V2', defaultValue: true);
}
