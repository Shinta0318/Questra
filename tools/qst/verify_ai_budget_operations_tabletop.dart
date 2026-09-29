import 'dart:io';

void main() {
  final failures = <String>[];
  final required = <String, List<String>>{
    'docs/qst/AI_BUDGET_OPERATIONS_TABLETOP.yaml': [
      'status: design_tabletop_completed_hosted_drill_pending',
      'provider_outage',
      'settlement_response_lost_after_commit',
      'reconciliation_queue_backlog',
      'incorrect_correction_applied',
      'cross_owner_or_negative_counter',
      'acknowledge_minutes:',
      'contain_minutes:',
      'recovery_minutes:',
      'create_separate_compensating_request_from_current_snapshot',
      'delete_or_rewrite_prior_audit: prohibited',
      'current_decision: no_go',
      'tabletop_is_hosted_execution_evidence: false',
    ],
    'docs/product/ai_budget_operations_recovery.md': [
      '破壊的down migrationや監査削除は行わない',
      '同じidempotency keyで再送',
      '別requestを作り',
      '別requester／approver',
      '技術用語、内部費用、model、provider、reservation、traceを表示しない',
      'External BetaはNO-GO',
    ],
    'docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml': [
      'decision: no_go',
      'distribution_ready: false',
      'any_blocked_gate_allows_distribution: false',
    ],
  };

  for (final entry in required.entries) {
    final file = File(entry.key);
    if (!file.existsSync()) {
      failures.add('Missing ${entry.key}');
      continue;
    }
    final text = file.readAsStringSync();
    for (final value in entry.value) {
      if (!text.contains(value)) {
        failures.add('${entry.key} missing "$value"');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('AI budget operations tabletop verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }
  stdout.writeln(
    'AI budget design tabletop contract passed; hosted recovery evidence remains pending.',
  );
}
