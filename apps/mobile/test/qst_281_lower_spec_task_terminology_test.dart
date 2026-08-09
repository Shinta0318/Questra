import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory('../..');
  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test('active domain and release guidance use the four-level journey', () {
    final activeDocuments = <String>[
      'docs/architecture/quest-mission-task-trail.md',
      'docs/architecture/mvp-navigation.md',
      'docs/product/real_device_beta_validation.md',
      'docs/product/store_listing_draft.md',
      'docs/product/STORE_READINESS.md',
      'docs/product/beta_readiness_report.md',
    ];

    for (final path in activeDocuments) {
      final content = read(path);
      expect(
        content,
        isNot(contains('Quest -> Mission -> Trail')),
        reason: '$path must not describe the retired three-level loop.',
      );
      expect(
        content,
        isNot(contains("today's Mission")),
        reason: '$path must treat Task as the executable daily unit.',
      );
    }

    final domain = read(activeDocuments.first);
    expect(domain, contains('Quest / Mission / Task / Trail'));
    expect(domain, contains('Mission: a verifiable intermediate outcome'));
    expect(domain, contains('Task: the smallest concrete action'));
  });

  test('privacy and device contracts explicitly include Task', () {
    final privacy = read(
      'apps/mobile/lib/features/trust/trust_privacy_review_service.dart',
    );
    final dataRequest = read(
      'apps/mobile/lib/features/trust/data_request_copy_service.dart',
    );
    final deviceEvidence = read('docs/qst/BETA_DEVICE_VALIDATION.yaml');
    final deviceVerifier = read(
      'tools/qst/verify_real_device_validation_readiness.dart',
    );

    expect(privacy, contains('Quest / Mission / Task / Trail'));
    expect(dataRequest, contains("'Quest', 'Mission', 'Task', 'Trail'"));
    expect(deviceEvidence, contains('quest_mission_task_trail:'));
    expect(deviceEvidence, isNot(contains('quest_mission_trail:')));
    expect(deviceVerifier, contains('Quest -> Mission -> Task -> Trail'));
  });

  test('historical terminology remains identifiable rather than rewritten', () {
    final compatibility = read('docs/architecture/quest-mission-trail.md');
    final historicalBacklog = read('docs/product/qst_backlog.md');

    expect(compatibility, contains('Legacy Document Path'));
    expect(compatibility, contains('quest-mission-task-trail.md'));
    expect(historicalBacklog, contains('Historical index'));
    expect(historicalBacklog, contains('Quest -> Mission -> Trail'));
  });

  test('active UI copy does not make Mission the daily action unit', () {
    final activeSources = <String>[
      'apps/mobile/lib/features/arc/arc_daily_greeting_service.dart',
      'apps/mobile/lib/features/arc/arc_guidance_service.dart',
      'apps/mobile/lib/features/home/home_screen.dart',
      'apps/mobile/lib/features/quest/quest_detail_screen.dart',
    ];
    for (final path in activeSources) {
      expect(
        read(path),
        isNot(contains('今日のMission')),
        reason: '$path must reserve daily concrete action wording for Task.',
      );
    }
  });
}
