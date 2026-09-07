class AuthFeatureFlags {
  const AuthFeatureFlags();

  bool get plainLanguageV2Enabled =>
      const bool.fromEnvironment('AUTH_PLAIN_LANGUAGE_V2', defaultValue: true);
}
