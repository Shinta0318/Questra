import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'analytics_event.dart';

abstract class AnalyticsRepository {
  Future<void> record(AnalyticsEvent event);
}

class LocalSafeAnalyticsRepository implements AnalyticsRepository {
  final List<AnalyticsEvent> _events = [];

  List<AnalyticsEvent> get events => List.unmodifiable(_events);

  @override
  Future<void> record(AnalyticsEvent event) async {
    _events.add(
      AnalyticsEvent(
        name: event.name,
        version: event.version,
        userId: event.userId,
        questId: event.questId,
        missionId: event.missionId,
        routeId: event.routeId,
        source: event.source,
        properties: AnalyticsPayloadRules.sanitize(event.properties),
        sessionId: event.sessionId,
        deviceType: event.deviceType,
        appVersion: event.appVersion,
        environment: event.environment,
        questDnaVersion: event.questDnaVersion,
        planningEngineVersion: event.planningEngineVersion,
        modelProvider: event.modelProvider,
        modelVersion: event.modelVersion,
        eventId: event.eventId,
        idempotencyKey: event.idempotencyKey,
        createdAt: event.createdAt,
      ),
    );
  }
}

class SupabaseAnalyticsRepository implements AnalyticsRepository {
  const SupabaseAnalyticsRepository(this.client);

  final SupabaseClient client;

  @override
  Future<void> record(AnalyticsEvent event) async {
    if (client.auth.currentUser == null) return;
    await client.rpc<void>(
      'record_quest_progress_event',
      params: {
        'p_event_name': event.name.storageKey,
        'p_event_version': event.version,
        'p_quest_id': event.questId,
        'p_mission_id': event.missionId,
        'p_route_id': event.routeId,
        'p_source': event.source.name,
        'p_occurred_at': event.createdAt.toUtc().toIso8601String(),
        'p_session_id': event.sessionId,
        'p_device_type': event.deviceType,
        'p_app_version': event.appVersion,
        'p_app_environment': event.environment,
        'p_quest_dna_version': event.questDnaVersion,
        'p_planning_engine_version': event.planningEngineVersion,
        'p_model_provider': event.modelProvider,
        'p_model_version': event.modelVersion,
        'p_metadata': AnalyticsPayloadRules.sanitize(event.properties),
        'p_idempotency_key': event.idempotencyKey,
      },
    );
  }
}

class NoopAnalyticsRepository implements AnalyticsRepository {
  const NoopAnalyticsRepository();

  @override
  Future<void> record(AnalyticsEvent event) async {}
}
