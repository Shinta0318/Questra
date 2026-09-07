class SettingsFeatureFlags {
  const SettingsFeatureFlags();

  bool get actionIndexV2Enabled => const bool.fromEnvironment(
    'SETTINGS_ACTION_INDEX_V2',
    defaultValue: true,
  );
}
