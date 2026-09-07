import 'dart:io';

import 'external_beta_go_no_go.dart';

void main() {
  final file = File(externalBetaDecisionPath);
  if (!file.existsSync()) _fail('External Beta decision file is missing.');
  final content = file.readAsStringSync().replaceAll('\r\n', '\n');
  final decision = evaluateExternalBetaReadiness();
  final failures = <String>[];

  _expect(content, 'decision: ${decision.decision}', failures);
  _expect(
    content,
    'distribution_ready: ${decision.distributionReady}',
    failures,
  );
  final recordedSourceCommit = RegExp(
    r'^candidate_source_commit: "([a-f0-9]{40})"$',
    multiLine: true,
  ).firstMatch(content)?.group(1);
  if (recordedSourceCommit == null) {
    failures.add('Candidate source commit is missing or invalid.');
  } else if (decision.distributionReady &&
      recordedSourceCommit != decision.sourceCommit) {
    failures.add('A GO decision must be bound to current HEAD.');
  }
  _expect(
    content,
    'latest_local_migration: "${decision.latestMigration}"',
    failures,
  );
  for (final gate in decision.gates) {
    _expect(content, '  - id: ${gate.id}', failures);
    _expect(content, '    status: ${gate.status}', failures);
  }
  for (final guardrail in const [
    'static_test_is_external_evidence: false',
    'local_fallback_is_provider_evidence: false',
    'stale_sha_evidence_allowed: false',
    'human_approval_inferred_from_code: false',
    'any_blocked_gate_allows_distribution: false',
    'destructive_database_rollback_allowed: false',
  ]) {
    _expect(content, guardrail, failures);
  }
  if (!decision.distributionReady && content.contains('decision: go')) {
    failures.add(
      'GO is forbidden while one or more evidence gates are blocked.',
    );
  }
  if (failures.isNotEmpty) {
    stderr.writeln('External Beta Go/No-Go verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    'External Beta Go/No-Go verification passed: ${decision.decision}.',
  );
}

void _expect(String content, String snippet, List<String> failures) {
  if (!content.contains(snippet)) failures.add('Missing or stale: $snippet');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
