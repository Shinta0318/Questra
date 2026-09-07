import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/analytics/analytics_event.dart';
import 'package:questra/core/analytics/analytics_repository.dart';
import 'package:questra/core/analytics/analytics_service.dart';

void main() {
  test('event names use stable storage keys', () {
    expect(AnalyticsEventName.questCreated.storageKey, 'quest_created');
    expect(AnalyticsEventName.arcChatSent.storageKey, 'arc_chat_sent');
    expect(
      AnalyticsEventName.onboardingCompleted.storageKey,
      'onboarding_completed',
    );
    expect(
      AnalyticsEventName.meaningfulProgressRecorded.storageKey,
      'meaningful_progress_recorded',
    );
  });

  test('payload sanitizer removes raw content fields', () {
    final safe = AnalyticsPayloadRules.sanitize({
      'category': '学習',
      'difficulty': 'normal',
      'title': '英語を話せるようになる',
      'content': '今日のTrail本文',
      'email': 'captain@example.com',
      'has_quest': true,
    });

    expect(safe, {'category': '学習', 'difficulty': 'normal', 'has_quest': true});
  });

  test('local repository stores only sanitized event payloads', () async {
    final repository = LocalSafeAnalyticsRepository();
    await repository.record(
      AnalyticsEvent(
        name: AnalyticsEventName.trailPosted,
        properties: {
          'surface': 'manual',
          'summary': 'private summary',
          'has_quest': false,
        },
      ),
    );

    expect(repository.events.single.properties, {
      'surface': 'manual',
      'has_quest': false,
    });
  });

  test('service helper emits beta-safe Quest creation payload', () async {
    final repository = LocalSafeAnalyticsRepository();
    final service = AnalyticsService(repository);

    await service.questCreated(
      category: '旅行',
      difficulty: 'normal',
      visibility: 'private',
    );

    final event = repository.events.single;
    expect(event.name, AnalyticsEventName.questCreated);
    expect(event.properties, {
      'category': '旅行',
      'difficulty': 'normal',
      'visibility': 'private',
    });
  });

  test('event identity is stable and raw Arc content is removed', () {
    final event = AnalyticsEvent(
      name: AnalyticsEventName.routeReplanned,
      questId: 'quest-id',
      idempotencyKey: 'route-replanned-once',
      properties: {'stage': 'planning', 'chat': 'private conversation'},
    );
    expect(event.idempotencyKey, 'route-replanned-once');
    expect(AnalyticsPayloadRules.sanitize(event.properties), {
      'stage': 'planning',
    });
  });

  test('analytics failure never blocks the primary action', () async {
    final service = AnalyticsService(_FailingAnalyticsRepository());
    await expectLater(
      service.progress(name: AnalyticsEventName.questUpdated, questId: 'q'),
      completes,
    );
  });

  test(
    'meaningful progress helper stores metric data without raw text',
    () async {
      final repository = LocalSafeAnalyticsRepository();
      final service = AnalyticsService(repository);

      await service.meaningfulProgress(
        questId: 'quest-id',
        missionId: 'mission-id',
        metricKey: 'weekly_meaningful_progress',
        surface: 'home_focus',
        progressBand: 'one_step',
        outcome: 'task_completed',
        hasTrail: true,
      );

      final event = repository.events.single;
      expect(event.name, AnalyticsEventName.meaningfulProgressRecorded);
      expect(event.properties, {
        'metric_key': 'weekly_meaningful_progress',
        'surface': 'home_focus',
        'progress_band': 'one_step',
        'outcome': 'task_completed',
        'has_trail': true,
      });
    },
  );

  test(
    'recovery and guardrail events remain allowlisted and bounded',
    () async {
      final repository = LocalSafeAnalyticsRepository();
      final service = AnalyticsService(repository);

      await service.recoveryActionSelected(
        questId: 'quest-id',
        missionId: 'mission-id',
        source: 'signal',
        outcome: 'rest_selected',
        accepted: true,
      );
      await service.guardrail(
        name: AnalyticsEventName.wellbeingGuardrailRecorded,
        guardrail: 'non_coercive_recovery',
        outcome: 'passed',
        consentScope: 'product_improvement',
      );
      await service.progress(
        name: AnalyticsEventName.trustFeedbackSubmitted,
        properties: {
          'outcome': 'positive',
          'message': 'private feedback',
          'email': 'captain@example.com',
        },
      );

      expect(repository.events[0].properties, {
        'source': 'signal',
        'outcome': 'rest_selected',
        'accepted': true,
      });
      expect(repository.events[1].properties, {
        'guardrail': 'non_coercive_recovery',
        'outcome': 'passed',
        'consent_scope': 'product_improvement',
      });
      expect(repository.events[2].properties, {'outcome': 'positive'});
    },
  );
}

class _FailingAnalyticsRepository implements AnalyticsRepository {
  @override
  Future<void> record(AnalyticsEvent event) => throw StateError('offline');
}
