import 'dart:io';

const evidencePath = 'docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml';

void main(List<String> arguments) {
  final requireHosted = arguments.contains('--require-hosted');
  final file = File(evidencePath);
  if (!file.existsSync()) _fail('Observability sink evidence is missing.');
  final content = file.readAsStringSync().replaceAll('\r\n', '\n');
  for (final required in const [
    'authenticated_owner_assignment: passed',
    'server_field_allowlist: passed',
    'direct_write_denied: passed',
    'per_owner_rate_limit: passed',
    'retention_30_days: passed',
    's0_s1_alert_queue: passed',
    'aggregate_slo_only: passed',
    'collection_default_off: passed',
    'transport_failure_isolated: passed',
    'arc_fallback_connected: passed',
    'raw_user_content_recorded: false',
    'account_identifier_in_alert_payload: false',
    'credential_or_token_recorded: false',
    'collection_enabled_without_flag: false',
    'local_contract_is_hosted_evidence: false',
  ]) {
    _expect(content, required);
  }
  if (requireHosted) {
    for (final required in const [
      'status: hosted_sink_alert_and_retention_verified',
      'working_tree_clean_at_execution: true',
      'hosted_sink_enabled: true',
      'migration_deployed: passed',
      'two_account_owner_isolation: passed',
      'retention_purge: passed',
      'alert_delivery_receipt: passed',
      's0_distribution_stop: passed',
      's1_rollout_pause: passed',
      'sink_failure_journey_continuity: passed',
    ]) {
      _expect(content, required);
    }
  }
  stdout.writeln(
    requireHosted
        ? 'Privacy-safe observability hosted gate passed.'
        : 'Privacy-safe observability local contract passed; hosted evidence remains pending.',
  );
}

void _expect(String content, String snippet) {
  if (!content.contains(snippet))
    _fail('Missing observability evidence: $snippet');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
