import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('../../supabase/tests/rls_behavior.sql').readAsStringSync();
  final evidence = File(
    '../../docs/qst/BETA_RLS_EVIDENCE.yaml',
  ).readAsStringSync();
  final capture = File(
    '../../tools/qst/capture_cloud_rls_evidence.ps1',
  ).readAsStringSync();
  final verifier = File(
    '../../tools/qst/verify_cloud_rls_evidence.dart',
  ).readAsStringSync();

  test('RLS behavior covers valid and invalid Trail parent writes', () {
    expect(
      sql,
      contains(
        'owner can create a Trail with matching Quest and Mission parents',
      ),
    );
    expect(
      sql,
      contains('owner cannot create a Trail with a Mission from another Quest'),
    );
    expect(
      sql,
      contains('owner cannot create a Trail under another owner journey'),
    );
    expect(sql, contains("'mission_record'"));
    expect(sql, contains('rollback;'));
  });

  test(
    'hosted evidence remains pending until the current candidate is replayed',
    () {
      expect(evidence, contains('trail_parent_contract:'));
      expect(evidence, contains('status: pending_current_candidate_replay'));
      expect(evidence, contains('owner_valid_parent_write: pending'));
      expect(evidence, contains('cross_quest_mission_write: pending'));
      expect(evidence, contains('cross_account_parent_write: pending'));
    },
  );

  test('capture and verifier require Trail parent outcomes', () {
    for (final token in const [
      'owner_valid_parent_write: passed',
      'cross_quest_mission_write: denied',
      'cross_account_parent_write: denied',
    ]) {
      expect(capture, contains(token));
      expect(verifier, contains(token));
    }
  });
}
