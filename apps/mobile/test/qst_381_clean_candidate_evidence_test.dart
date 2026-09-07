import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;

  test('clean candidate orchestrator invokes every external evidence gate', () {
    final script = File(
      '${repo.path}/tools/qst/run_clean_candidate_evidence_gate.ps1',
    ).readAsStringSync();
    for (final gate in [
      'verify_hosted_evidence_bundle.dart --require-cloud',
      'verify_physical_accessibility_evidence.dart --require-physical',
      'verify_dependency_notices.dart --require-release',
      'verify_arc_asset_provenance.dart --require-release',
      'verify_candidate_asset_package.dart --require-release',
      'verify_beta_feedback_readiness.dart --require-operations',
      'verify_runtime_slo_drill.dart --require-hosted',
      'quest_planning_release_gate.ps1',
      'verify_clean_candidate_evidence.dart',
    ]) {
      expect(script, contains(gate));
    }
  });

  test('cross-evidence verifier rejects source changes and stale SHA evidence', () {
    final verifier = File(
      '${repo.path}/tools/qst/verify_clean_candidate_evidence.dart',
    ).readAsStringSync();
    expect(verifier, contains('nonEvidenceChanges'));
    expect(verifier, contains('candidate_source_commit'));
    expect(verifier, contains('candidate_sha'));
    expect(verifier, contains('Candidate artifact checksum is missing'));
    expect(verifier, contains("aiReport['passed'] != true"));
  });
}
