import 'dart:io';

void main() {
  final failures = <String>[];
  final required = <String, List<String>>{
    'docs/qst/INCIDENT_TABLETOP.yaml': [
      's0_cross_account_visibility',
      's0_repeated_data_loss',
      's1_auth_or_persistence_degradation',
      's1_ai_provider_degradation',
      'stop_distribution',
      'pause_ai_planning',
      'template_missions_allowed: false',
      'destructive_down_migration_automatic: false',
      'tabletop_is_live_execution_evidence: false',
    ],
    'docs/product/runtime_slo_dashboard_and_drill.md': [
      '配布停止',
      '破壊的DB down migrationは自動実行しない',
      'rollout拡大を停止',
    ],
    'docs/qst/BETA_FEEDBACK_OPERATIONS.yaml': [
      'any_open_s0_or_release_manager_stop',
      'acknowledge_within_1_hour_and_stop_expansion',
      'invented_operator_evidence_allowed: false',
    ],
  };
  for (final entry in required.entries) {
    final file = File(entry.key);
    if (!file.existsSync()) {
      failures.add('Missing ${entry.key}');
      continue;
    }
    final text = file.readAsStringSync();
    for (final snippet in entry.value) {
      if (!text.contains(snippet))
        failures.add('${entry.key} missing "$snippet"');
    }
  }
  if (failures.isNotEmpty) {
    stderr.writeln('Incident tabletop verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    'Incident tabletop contract passed; named-owner live drill remains pending.',
  );
}
