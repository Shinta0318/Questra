import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tools/qst/verify_external_beta_go_no_go.dart' as gate_verifier;

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

  test(
    'cross-evidence verifier rejects source changes and stale SHA evidence',
    () {
      final verifier = File(
        '${repo.path}/tools/qst/verify_clean_candidate_evidence.dart',
      ).readAsStringSync();
      expect(verifier, contains('nonEvidenceChanges'));
      expect(verifier, contains('candidate_source_commit'));
      expect(verifier, contains('candidate_sha'));
      expect(verifier, contains('Candidate artifact checksum is missing'));
      expect(verifier, contains("aiReport['passed'] != true"));
    },
  );

  test('candidate cleanliness is checked before Flutter generates files', () {
    final workflow = File(
      '${repo.path}/.github/workflows/release-gate.yml',
    ).readAsStringSync();
    final preflight = workflow.indexOf('name: Candidate source preflight');
    final dependencyResolution = workflow.indexOf(
      'name: Resolve Flutter dependencies',
    );
    final releaseContracts = workflow.indexOf(
      'name: Supabase release contracts',
    );

    expect(preflight, greaterThanOrEqualTo(0));
    expect(preflight, lessThan(dependencyResolution));
    expect(
      workflow.substring(releaseContracts),
      isNot(contains('verify_candidate_preflight.dart --require-clean')),
    );
  });

  test('only a distributable GO decision must bind current HEAD', () {
    final verifier = File(
      '${repo.path}/tools/qst/verify_external_beta_go_no_go.dart',
    ).readAsStringSync();
    expect(
      verifier,
      contains('Candidate source commit is missing or invalid.'),
    );
    expect(verifier, contains('decision.distributionReady'));
    expect(verifier, contains('A GO decision must be bound to current HEAD.'));
    expect(verifier, contains('externalBetaGateBlock(content, gate.id)'));
    expect(
      verifier,
      contains('Gate IDs are missing, duplicated, or unexpected.'),
    );
    expect(
      verifier,
      contains(r'Passed gate ${gate.id} must not declare a blocker.'),
    );
    expect(verifier, contains('_yaml(gate.blocker)'));
    expect(
      verifier,
      contains('decision.gates.where((gate) => !gate.passed).length'),
    );
  });

  test('external beta statuses are scoped to their own gate block', () {
    const content = '''
gates:
  - id: first_gate
    title: "First"
    status: passed
    evidence:
      - "first.txt"
  - id: second_gate
    title: "Second"
    status: blocked
    evidence:
      - "second.txt"
    blocker: "Missing external evidence"
guardrails:
  static_test_is_external_evidence: false
''';

    final first = gate_verifier.externalBetaGateBlock(content, 'first_gate');
    final second = gate_verifier.externalBetaGateBlock(content, 'second_gate');

    expect(first, contains('status: passed'));
    expect(first, isNot(contains('status: blocked')));
    expect(first, isNot(contains('second.txt')));
    expect(second, contains('status: blocked'));
    expect(second, isNot(contains('status: passed')));
    expect(second, contains('Missing external evidence'));
    expect(
      gate_verifier.externalBetaGateBlock(content, 'missing_gate'),
      isNull,
    );
  });
}
