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
}
