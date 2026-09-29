import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/analytics/analytics_event.dart';
import 'package:questra/core/analytics/analytics_repository.dart';
import 'package:questra/core/analytics/analytics_service.dart';

void main() {
  test('Trail journey events use stable storage keys', () {
    expect(
      AnalyticsEventName.trailComposerOpened.storageKey,
      'trail_composer_opened',
    );
    expect(
      AnalyticsEventName.trailParentSelected.storageKey,
      'trail_parent_selected',
    );
    expect(
      AnalyticsEventName.trailMissionRecoveryOpened.storageKey,
      'trail_mission_recovery_opened',
    );
    expect(
      AnalyticsEventName.trailDraftConflictResolved.storageKey,
      'trail_draft_conflict_resolved',
    );
    expect(
      AnalyticsEventName.trailComposerCompleted.storageKey,
      'trail_composer_completed',
    );
  });

  test('Trail journey analytics contains no content or entity IDs', () async {
    final repository = LocalSafeAnalyticsRepository();
    final service = AnalyticsService(repository);

    await service.trailJourney(
      name: AnalyticsEventName.trailParentSelected,
      surface: 'trail_composer',
      outcome: 'selected',
      hasQuest: true,
      hasMission: true,
    );

    final event = repository.events.single;
    expect(event.userId, isNull);
    expect(event.questId, isNull);
    expect(event.missionId, isNull);
    expect(event.routeId, isNull);
    expect(event.properties, {
      'surface': 'trail_composer',
      'outcome': 'selected',
      'has_quest': true,
      'has_mission': true,
      'source': 'user',
    });
    expect(
      event.properties.keys.toSet().intersection(
        AnalyticsPayloadRules.blockedKeys,
      ),
      isEmpty,
    );
  });
}
