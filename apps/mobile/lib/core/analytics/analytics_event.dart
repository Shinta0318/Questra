import 'package:uuid/uuid.dart';

const _analyticsUuid = Uuid();

enum AnalyticsEventName {
  questCreated,
  questUpdated,
  questDeleted,
  questStarted,
  questPaused,
  questResumed,
  questCompleted,
  questAbandoned,
  questStageChanged,
  questPlanGenerated,
  questPlanApproved,
  questPlanRejected,
  questPlanRegenerated,
  questProposalViewed,
  questProposalSelected,
  missionCreated,
  missionUpdated,
  missionStarted,
  missionCompleted,
  missionSkipped,
  missionDeleted,
  missionRescheduled,
  missionRegenerated,
  missionReordered,
  missionSupportRequested,
  routeCreated,
  routeUpdated,
  routeReplanned,
  routeApproved,
  routeRejected,
  routeRolledBack,
  businessQuestViewed,
  businessQuestCopied,
  businessQuestStarted,
  offerViewed,
  offerSaved,
  offerDismissed,
  offerAccepted,
  offerReported,
  providerContactRequested,
  offerAdoptedToMission,
  offerActionStarted,
  offerActionCompleted,
  missionCompletedAfterOffer,
  questStageAdvancedAfterOffer,
  questCompletedAfterOffer,
  userHelpfulnessSubmitted,
  refundOrCancellationRecorded,
  trailPosted,
  arcChatSent,
  guildDraftCreated,
  mediaAttached,
  onboardingCompleted,
  experienceSettingsOpened,
  experienceSettingChanged,
  arcTapped,
  arcLongPressed,
  missionCompletedBySwipe,
  missionCompletedByButton,
  questCompletionEffectShown,
  completionEffectSkipped,
  soundEffectEnabled,
  hapticsDisabled,
  powerSavingEnabled,
}

class AnalyticsEvent {
  AnalyticsEvent({
    required this.name,
    this.version = 1,
    this.userId,
    this.questId,
    this.missionId,
    this.routeId,
    this.source = AnalyticsEventSource.user,
    this.properties = const {},
    this.sessionId,
    this.deviceType,
    this.appVersion,
    this.environment = 'production',
    this.questDnaVersion,
    this.planningEngineVersion,
    this.modelProvider,
    this.modelVersion,
    String? eventId,
    String? idempotencyKey,
    DateTime? createdAt,
  }) : eventId = eventId ?? _analyticsUuid.v4(),
       createdAt = createdAt ?? DateTime.now(),
       idempotencyKey = idempotencyKey ?? eventId ?? _analyticsUuid.v4();

  final String eventId;
  final AnalyticsEventName name;
  final int version;
  final String? userId;
  final String? questId;
  final String? missionId;
  final String? routeId;
  final AnalyticsEventSource source;
  final Map<String, Object?> properties;
  final String? sessionId;
  final String? deviceType;
  final String? appVersion;
  final String environment;
  final int? questDnaVersion;
  final String? planningEngineVersion;
  final String? modelProvider;
  final String? modelVersion;
  final String idempotencyKey;
  final DateTime createdAt;
}

enum AnalyticsEventSource { user, arc, system, business }

extension AnalyticsEventNameStorage on AnalyticsEventName {
  String get storageKey {
    return switch (this) {
      AnalyticsEventName.questCreated => 'quest_created',
      AnalyticsEventName.questUpdated => 'quest_updated',
      AnalyticsEventName.questDeleted => 'quest_deleted',
      AnalyticsEventName.questStarted => 'quest_started',
      AnalyticsEventName.questPaused => 'quest_paused',
      AnalyticsEventName.questResumed => 'quest_resumed',
      AnalyticsEventName.questCompleted => 'quest_completed',
      AnalyticsEventName.questAbandoned => 'quest_abandoned',
      AnalyticsEventName.questStageChanged => 'quest_stage_changed',
      AnalyticsEventName.questPlanGenerated => 'quest_plan_generated',
      AnalyticsEventName.questPlanApproved => 'quest_plan_approved',
      AnalyticsEventName.questPlanRejected => 'quest_plan_rejected',
      AnalyticsEventName.questPlanRegenerated => 'quest_plan_regenerated',
      AnalyticsEventName.questProposalViewed => 'quest_proposal_viewed',
      AnalyticsEventName.questProposalSelected => 'quest_proposal_selected',
      AnalyticsEventName.missionCreated => 'mission_created',
      AnalyticsEventName.missionUpdated => 'mission_updated',
      AnalyticsEventName.missionStarted => 'mission_started',
      AnalyticsEventName.missionCompleted => 'mission_completed',
      AnalyticsEventName.missionSkipped => 'mission_skipped',
      AnalyticsEventName.missionDeleted => 'mission_deleted',
      AnalyticsEventName.missionRescheduled => 'mission_rescheduled',
      AnalyticsEventName.missionRegenerated => 'mission_regenerated',
      AnalyticsEventName.missionReordered => 'mission_reordered',
      AnalyticsEventName.missionSupportRequested => 'mission_support_requested',
      AnalyticsEventName.routeCreated => 'route_created',
      AnalyticsEventName.routeUpdated => 'route_updated',
      AnalyticsEventName.routeReplanned => 'route_replanned',
      AnalyticsEventName.routeApproved => 'route_approved',
      AnalyticsEventName.routeRejected => 'route_rejected',
      AnalyticsEventName.routeRolledBack => 'route_rolled_back',
      AnalyticsEventName.businessQuestViewed => 'business_quest_viewed',
      AnalyticsEventName.businessQuestCopied => 'business_quest_copied',
      AnalyticsEventName.businessQuestStarted => 'business_quest_started',
      AnalyticsEventName.offerViewed => 'offer_viewed',
      AnalyticsEventName.offerSaved => 'offer_saved',
      AnalyticsEventName.offerDismissed => 'offer_dismissed',
      AnalyticsEventName.offerAccepted => 'offer_accepted',
      AnalyticsEventName.offerReported => 'offer_reported',
      AnalyticsEventName.providerContactRequested =>
        'provider_contact_requested',
      AnalyticsEventName.offerAdoptedToMission => 'offer_adopted_to_mission',
      AnalyticsEventName.offerActionStarted => 'offer_action_started',
      AnalyticsEventName.offerActionCompleted => 'offer_action_completed',
      AnalyticsEventName.missionCompletedAfterOffer =>
        'mission_completed_after_offer',
      AnalyticsEventName.questStageAdvancedAfterOffer =>
        'quest_stage_advanced_after_offer',
      AnalyticsEventName.questCompletedAfterOffer =>
        'quest_completed_after_offer',
      AnalyticsEventName.userHelpfulnessSubmitted =>
        'user_helpfulness_submitted',
      AnalyticsEventName.refundOrCancellationRecorded =>
        'refund_or_cancellation_recorded',
      AnalyticsEventName.trailPosted => 'trail_posted',
      AnalyticsEventName.arcChatSent => 'arc_chat_sent',
      AnalyticsEventName.guildDraftCreated => 'guild_draft_created',
      AnalyticsEventName.mediaAttached => 'media_attached',
      AnalyticsEventName.onboardingCompleted => 'onboarding_completed',
      AnalyticsEventName.experienceSettingsOpened =>
        'experience_settings_opened',
      AnalyticsEventName.experienceSettingChanged =>
        'experience_setting_changed',
      AnalyticsEventName.arcTapped => 'arc_tapped',
      AnalyticsEventName.arcLongPressed => 'arc_long_pressed',
      AnalyticsEventName.missionCompletedBySwipe =>
        'mission_completed_by_swipe',
      AnalyticsEventName.missionCompletedByButton =>
        'mission_completed_by_button',
      AnalyticsEventName.questCompletionEffectShown =>
        'quest_completion_effect_shown',
      AnalyticsEventName.completionEffectSkipped => 'completion_effect_skipped',
      AnalyticsEventName.soundEffectEnabled => 'sound_effect_enabled',
      AnalyticsEventName.hapticsDisabled => 'haptics_disabled',
      AnalyticsEventName.powerSavingEnabled => 'power_saving_enabled',
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
    'setting',
    'value',
    'interaction',
    'progress_band',
    'stage',
    'reason_code',
    'proposal_type',
    'support_type',
    'outcome',
    'source_type',
    'plan_quality_band',
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
    'phone',
    'address',
    'prompt',
    'chat',
    'memory',
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
