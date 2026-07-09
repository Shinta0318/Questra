enum AnalyticsEventName {
  questCreated,
  missionCompleted,
  trailPosted,
  arcChatSent,
  guildDraftCreated,
  mediaAttached,
  onboardingCompleted,
}

class AnalyticsEvent {
  AnalyticsEvent({
    required this.name,
    this.userId,
    this.properties = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final AnalyticsEventName name;
  final String? userId;
  final Map<String, Object?> properties;
  final DateTime createdAt;
}

extension AnalyticsEventNameStorage on AnalyticsEventName {
  String get storageKey {
    return switch (this) {
      AnalyticsEventName.questCreated => 'quest_created',
      AnalyticsEventName.missionCompleted => 'mission_completed',
      AnalyticsEventName.trailPosted => 'trail_posted',
      AnalyticsEventName.arcChatSent => 'arc_chat_sent',
      AnalyticsEventName.guildDraftCreated => 'guild_draft_created',
      AnalyticsEventName.mediaAttached => 'media_attached',
      AnalyticsEventName.onboardingCompleted => 'onboarding_completed',
    };
  }
}

class AnalyticsPayloadRules {
  const AnalyticsPayloadRules._();

  static const allowedKeys = {
    'category',
    'difficulty',
    'status',
    'visibility',
    'source',
    'surface',
    'media_type',
    'has_quest',
    'has_mission',
    'has_trail',
    'quest_interest',
    'signal_frequency',
  };

  static const blockedKeys = {
    'title',
    'description',
    'content',
    'summary',
    'message',
    'text',
    'email',
    'nickname',
    'name',
    'url',
    'path',
  };

  static Map<String, Object?> sanitize(Map<String, Object?> properties) {
    final safe = <String, Object?>{};
    for (final entry in properties.entries) {
      if (!allowedKeys.contains(entry.key) || blockedKeys.contains(entry.key)) {
        continue;
      }
      final value = entry.value;
      if (value is String || value is num || value is bool || value == null) {
        safe[entry.key] = value;
      }
    }
    return safe;
  }
}
