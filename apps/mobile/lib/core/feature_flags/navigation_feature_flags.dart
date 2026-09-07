class NavigationFeatureFlags {
  const NavigationFeatureFlags();

  /// Kill switch for height-aware rail selection and compact labels.
  bool get heightAwareV2Enabled => const bool.fromEnvironment(
    'NAVIGATION_HEIGHT_AWARE_V2',
    defaultValue: true,
  );
}
