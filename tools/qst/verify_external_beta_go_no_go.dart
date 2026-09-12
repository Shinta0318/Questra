import 'dart:io';

import 'external_beta_go_no_go.dart';

void main() {
  final file = File(externalBetaDecisionPath);
  if (!file.existsSync()) _fail('External Beta decision file is missing.');
  final content = file.readAsStringSync().replaceAll('\r\n', '\n');
  final decision = evaluateExternalBetaReadiness();
  final failures = <String>[];

  _expect(
    content,
    '  passed: ${decision.gates.where((gate) => gate.passed).length}',
    failures,
  );
  _expect(
    content,
    '  blocked: ${decision.gates.where((gate) => !gate.passed).length}',
    failures,
  );
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
  final declaredGateIds = RegExp(
    r'^  - id: ([a-z0-9_]+)$',
    multiLine: true,
  ).allMatches(content).map((match) => match.group(1)!).toList();
  final expectedGateIds = decision.gates.map((gate) => gate.id).toList();
  if (declaredGateIds.length != expectedGateIds.length ||
      declaredGateIds.toSet().length != declaredGateIds.length ||
      !expectedGateIds.every(declaredGateIds.contains)) {
    failures.add('Gate IDs are missing, duplicated, or unexpected.');
  }
  for (final gate in decision.gates) {
    final block = externalBetaGateBlock(content, gate.id);
    if (block == null) {
      failures.add('Missing gate block: ${gate.id}');
      continue;
    }
    _expect(block, '    title: "${_yaml(gate.title)}"', failures);
    _expect(block, '    status: ${gate.status}', failures);
    for (final evidence in gate.evidence) {
      _expect(block, '      - "$evidence"', failures);
    }
    if (gate.passed) {
      if (block.contains('    blocker:')) {
        failures.add('Passed gate ${gate.id} must not declare a blocker.');
      }
    } else {
      _expect(block, '    blocker: "${_yaml(gate.blocker)}"', failures);
    }
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

String? externalBetaGateBlock(String content, String gateId) {
  return RegExp(
    '^  - id: ${RegExp.escape(gateId)}\\s*\$([\\s\\S]*?)(?=^  - id: |^guardrails:)',
    multiLine: true,
  ).firstMatch(content)?.group(0);
}

String _yaml(String value) => value.replaceAll('"', '\\"');

void _expect(String content, String snippet, List<String> failures) {
  if (!content.contains(snippet)) failures.add('Missing or stale: $snippet');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
