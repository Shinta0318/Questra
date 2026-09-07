import 'dart:io';

void main() {
  final failures = <String>[];
  final runner = _read('tools/qst/run_hosted_evidence_gate.ps1', failures);
  final rls = _read('supabase/tests/rls_behavior.sql', failures);
  final rights = _read(
    'supabase/migrations/202608250007_data_rights_fulfillment_sla.sql',
    failures,
  );
  final observability = _read(
    'supabase/migrations/202608250008_privacy_safe_runtime_observability.sql',
    failures,
  ) +
      _read(
        'supabase/migrations/202608250009_runtime_observability_exact_operator_drill.sql',
        failures,
      );
  final worker = _read(
    'supabase/functions/process-data-rights-requests/index.ts',
    failures,
  );
  for (final required in const [
    'Hosted evidence must start from a clean candidate working tree.',
    'verify_hosted_evidence_runner_v2.dart',
    'bootstrap_supabase_beta.ps1',
    'capture_cloud_rls_evidence.ps1',
    'run_qst199_cloud_acceptance.ps1',
    'verify_hosted_evidence_bundle.dart',
    'run_data_rights_hosted_drill.ps1',
    'run_observability_hosted_drill.ps1',
    'data_rights_fulfillment: passed_retention_review_pending',
    'runtime_observability: passed',
    'physical_accessibility: pending_qst376',
  ]) {
    _expect(
      runner,
      required,
      'tools/qst/run_hosted_evidence_gate.ps1',
      failures,
    );
  }
  for (final required in const [
    'data_rights_fulfillment_receipts',
    'runtime_evidence_events',
    'runtime_evidence_alert_queue',
    'app user cannot bypass Data Rights request RPC',
    'app user cannot bypass runtime evidence RPC',
    'app user cannot read runtime alert queue',
  ]) {
    _expect(rls, required, 'supabase/tests/rls_behavior.sql', failures);
  }
  for (final required in const [
    'fulfill_pending_consent_withdrawals',
    'resolve_data_correction_request',
    'revoke insert, update, delete on public.data_rights_requests',
  ]) {
    _expect(rights, required, 'QST-368 migration', failures);
  }
  for (final required in const [
    'record_runtime_evidence',
    'runtime_evidence_rate_buckets',
    'claim_runtime_evidence_alerts',
    'purge_expired_runtime_evidence',
    'claim_runtime_evidence_alert',
    'purge_runtime_evidence_event',
  ]) {
    _expect(observability, required, 'QST-370 migration', failures);
  }
  for (final required in const [
    'fulfill_pending_consent_withdrawals',
    'classifyWorkerError',
    'constantTimeEqual',
  ]) {
    _expect(worker, required, 'Data Rights worker', failures);
  }
  if (failures.isNotEmpty) {
    stderr.writeln('Hosted evidence runner V2 verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    'Hosted evidence runner V2 contract passed; cloud execution remains explicit.',
  );
}

String _read(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing required file: $path');
    return '';
  }
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

void _expect(
  String content,
  String snippet,
  String path,
  List<String> failures,
) {
  if (!content.contains(snippet)) failures.add('Missing "$snippet" in $path.');
}
