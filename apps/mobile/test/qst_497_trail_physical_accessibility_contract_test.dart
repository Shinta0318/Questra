import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final evidence = File(
    '../../docs/qst/PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml',
  ).readAsStringSync();
  final recorder = File(
    '../../tools/qst/record_physical_accessibility_evidence.dart',
  ).readAsStringSync();
  final verifier = File(
    '../../tools/qst/verify_physical_accessibility_evidence.dart',
  ).readAsStringSync();

  const scenarios = [
    'trail_quest_mission_selection',
    'trail_japanese_ime_composition',
    'trail_large_text_200',
    'trail_talkback_reading_order',
    'trail_error_and_save_feedback',
  ];

  test('pending evidence names every required Trail physical scenario', () {
    for (final scenario in scenarios) {
      expect(evidence, contains('$scenario: pending'));
    }
    expect(evidence, contains('status: pending_physical_execution'));
  });

  test('recorder requires explicit Trail scenario confirmation', () {
    for (final scenario in scenarios) {
      expect(recorder, contains("'$scenario'"));
      expect(recorder, contains('--\$key=true'));
    }
  });

  test('physical verifier requires each Trail scenario to pass', () {
    expect(verifier, contains('trailJourneyScenarios'));
    expect(verifier, contains("_expect(content, '\$scenario: passed')"));
    expect(verifier, contains('automated_test_replaces_human_evidence: false'));
  });
}
