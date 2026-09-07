class NotificationFeatureFlags {
  const NotificationFeatureFlags();

  bool get policyV2Enabled =>
      const bool.fromEnvironment('NOTIFICATION_POLICY_V2', defaultValue: true);
}
