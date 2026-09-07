import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../config/supabase_config.dart';
import 'analytics_event.dart';
import 'analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAnalyticsRepository(Supabase.instance.client);
  }
  return LocalSafeAnalyticsRepository();
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref.watch(analyticsRepositoryProvider));
});

class AnalyticsService {
  const AnalyticsService(this._repository);

  final AnalyticsRepository _repository;

  Future<void> track(AnalyticsEvent event) async {
    try {
      await _repository.record(event);
    } catch (_) {
      // Progress intelligence is best-effort and never blocks a Quest action.
    }
  }

  Future<void> questCreated({
    String? userId,
    String? questId,
    required String category,
    required String difficulty,
    required String visibility,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.questCreated,
        userId: userId,
        questId: questId,
        properties: {
          'category': category,
          'difficulty': difficulty,
          'visibility': visibility,
        },
      ),
    );
  }

  Future<void> progress({
    required AnalyticsEventName name,
    String? userId,
    String? questId,
    String? missionId,
    String? routeId,
    AnalyticsEventSource source = AnalyticsEventSource.user,
    Map<String, Object?> properties = const {},
    String? idempotencyKey,
  }) {
    return track(
      AnalyticsEvent(
        name: name,
        userId: userId,
        questId: questId,
        missionId: missionId,
        routeId: routeId,
        source: source,
        properties: properties,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  Future<void> missionCompleted({
    String? userId,
    required String difficulty,
    required bool hasQuest,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.missionCompleted,
        userId: userId,
        properties: {'difficulty': difficulty, 'has_quest': hasQuest},
      ),
    );
  }

  Future<void> trailPosted({
    String? userId,
    required String surface,
    required bool hasQuest,
    required bool hasMission,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.trailPosted,
        userId: userId,
        properties: {
          'surface': surface,
          'has_quest': hasQuest,
          'has_mission': hasMission,
        },
      ),
    );
  }

  Future<void> arcChatSent({
    String? userId,
    required bool hasQuest,
    required bool hasTrail,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.arcChatSent,
        userId: userId,
        properties: {'has_quest': hasQuest, 'has_trail': hasTrail},
      ),
    );
  }

  Future<void> guildDraftCreated({String? userId, required String source}) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.guildDraftCreated,
        userId: userId,
        properties: {'source': source},
      ),
    );
  }

  Future<void> mediaAttached({
    String? userId,
    required String mediaType,
    required String surface,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.mediaAttached,
        userId: userId,
        properties: {'media_type': mediaType, 'surface': surface},
      ),
    );
  }

  Future<void> onboardingCompleted({
    String? userId,
    required String questInterest,
    required String signalFrequency,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.onboardingCompleted,
        userId: userId,
        properties: {
          'quest_interest': questInterest,
          'signal_frequency': signalFrequency,
        },
      ),
    );
  }

  Future<void> activationStepCompleted({
    String? userId,
    required String activationStage,
    required String surface,
    required String outcome,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.activationStepCompleted,
        userId: userId,
        properties: {
          'activation_stage': activationStage,
          'surface': surface,
          'outcome': outcome,
        },
      ),
    );
  }

  Future<void> meaningfulProgress({
    String? userId,
    String? questId,
    String? missionId,
    required String metricKey,
    required String surface,
    required String progressBand,
    required String outcome,
    bool hasTrail = false,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.meaningfulProgressRecorded,
        userId: userId,
        questId: questId,
        missionId: missionId,
        properties: {
          'metric_key': metricKey,
          'surface': surface,
          'progress_band': progressBand,
          'outcome': outcome,
          'has_trail': hasTrail,
        },
      ),
    );
  }

  Future<void> recoveryActionSelected({
    String? userId,
    String? questId,
    String? missionId,
    required String source,
    required String outcome,
    required bool accepted,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.recoveryActionSelected,
        userId: userId,
        questId: questId,
        missionId: missionId,
        properties: {
          'source': source,
          'outcome': outcome,
          'accepted': accepted,
        },
      ),
    );
  }

  Future<void> guardrail({
    String? userId,
    required AnalyticsEventName name,
    required String guardrail,
    required String outcome,
    String? costBand,
    String? latencyBand,
    String? consentScope,
  }) {
    final properties = <String, Object?>{
      'guardrail': guardrail,
      'outcome': outcome,
    };
    if (costBand != null) properties['cost_band'] = costBand;
    if (latencyBand != null) properties['latency_band'] = latencyBand;
    if (consentScope != null) properties['consent_scope'] = consentScope;
    return track(
      AnalyticsEvent(
        name: name,
        userId: userId,
        source: AnalyticsEventSource.system,
        properties: properties,
      ),
    );
  }
}
