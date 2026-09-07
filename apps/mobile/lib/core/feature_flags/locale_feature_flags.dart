class LocaleFeatureFlags {
  const LocaleFeatureFlags();

  bool get localizedJourneyCopyV2Enabled =>
      const bool.fromEnvironment('LOCALE_COPY_V2', defaultValue: true);
}
