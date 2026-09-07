import 'dart:io';

import '../../apps/mobile/lib/core/observability/runtime_slo.dart';

const evidencePath = 'docs/qst/RUNTIME_SLO_DRILL.yaml';

Future<void> main() async {
  const evaluator = RuntimeSloEvaluator();
  final healthy = evaluator.evaluate(
    const RuntimeSloWindow(
      coreOperations: 10000,
      failedCoreOperations: 2,
      sessions: 10000,
      crashedSessions: 2,
      mutationP95Ms: 420,
      listReadP95Ms: 850,
    ),
  );
  final s1 = evaluator.evaluate(
    const RuntimeSloWindow(
      coreOperations: 1000,
      failedCoreOperations: 5,
      sessions: 1000,
      crashedSessions: 6,
      mutationP95Ms: 750,
      listReadP95Ms: 1200,
    ),
  );
  final s0 = evaluator.evaluate(
    const RuntimeSloWindow(
      coreOperations: 10000,
      failedCoreOperations: 0,
      sessions: 10000,
      crashedSessions: 0,
      mutationP95Ms: 300,
      listReadP95Ms: 600,
      crossAccountViolation: true,
    ),
  );
  if (!healthy.distributionAllowed ||
      s1.distributionAllowed ||
      s1.rollbackRequired ||
      !s0.rollbackRequired) {
    stderr.writeln('Runtime SLO drill assertions failed.');
    exit(1);
  }
  final sha = (await Process.run('git', [
    'rev-parse',
    'HEAD',
  ])).stdout.toString().trim();
  final dirty = (await Process.run('git', [
    'status',
    '--porcelain',
  ])).stdout.toString().trim().isNotEmpty;
  final generatedAt = DateTime.now().toUtc().toIso8601String();
  File(evidencePath).writeAsStringSync('''version: 1
status: local_dry_run_passed_hosted_pending
generated_at_utc: "$generatedAt"
candidate_source_commit: "$sha"
working_tree_clean_at_execution: ${!dirty}
hosted_sink_connected: false
alert_delivery_receipt_verified: false
rollback_execution_verified: false
privacy:
  raw_user_content_recorded: false
  account_identifier_recorded: false
  credential_or_token_recorded: false
scenarios:
  healthy:
    decision: continue_internal_distribution
    passed: true
  s1_slo_breach:
    decision: pause_rollout_and_page_incident_owner
    passed: true
  s0_cross_account:
    decision: stop_distribution_and_rollback_candidate
    passed: true
release_policy:
  local_dry_run_is_hosted_evidence: false
  s0_allows_distribution: false
  s1_allows_rollout_expansion: false
''');
  stdout.writeln(
    'Runtime SLO local drill passed; hosted alert evidence is pending.',
  );
}
