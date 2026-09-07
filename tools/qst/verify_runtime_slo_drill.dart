import 'dart:io';

const evidencePath = 'docs/qst/RUNTIME_SLO_DRILL.yaml';

void main(List<String> arguments) {
  final requireHosted = arguments.contains('--require-hosted');
  final file = File(evidencePath);
  if (!file.existsSync()) _fail('Runtime SLO drill evidence is missing.');
  final evidence = file.readAsStringSync().replaceAll('\r\n', '\n');
  for (final required in [
    'raw_user_content_recorded: false',
    'account_identifier_recorded: false',
    'credential_or_token_recorded: false',
    'decision: continue_internal_distribution',
    'decision: pause_rollout_and_page_incident_owner',
    'decision: stop_distribution_and_rollback_candidate',
    'local_dry_run_is_hosted_evidence: false',
    's0_allows_distribution: false',
    's1_allows_rollout_expansion: false',
  ]) {
    if (!evidence.contains(required)) _fail('Missing SLO evidence: $required');
  }
  if (RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  ).hasMatch(evidence)) {
    _fail('Runtime evidence contains a possible email address.');
  }
  if (requireHosted) {
    for (final required in [
      'status: hosted_alert_and_rollback_verified',
      'working_tree_clean_at_execution: true',
      'hosted_sink_connected: true',
      'alert_delivery_receipt_verified: true',
      'rollback_execution_verified: true',
    ]) {
      if (!evidence.contains(required))
        _fail('Hosted SLO gate missing: $required');
    }
  }
  stdout.writeln(
    requireHosted
        ? 'Runtime SLO hosted drill verification passed.'
        : 'Runtime SLO local drill contract passed; hosted evidence remains pending.',
  );
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
