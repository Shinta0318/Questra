import 'dart:io';

const evidencePath = 'docs/qst/DATA_RIGHTS_FULFILLMENT_DRILL.yaml';
const retentionPath = 'docs/qst/DATA_RIGHTS_RETENTION_REGISTER.yaml';

void main(List<String> arguments) {
  final requireHosted = arguments.contains('--require-hosted');
  final requireHostedOperations = arguments.contains(
    '--require-hosted-operations',
  );
  final evidence = _read(evidencePath);
  final retention = _read(retentionPath);
  for (final required in const [
    'correction_sla_contract: passed',
    'correction_resolution_allowlist: passed',
    'withdrawal_transaction_contract: passed',
    'deletion_cancellation_window: passed',
    'deletion_retry_classification: passed',
    'content_free_fulfillment_receipt: passed',
    'aggregate_metrics_only: passed',
    'worker_response_has_no_request_id: passed',
    'request_content_recorded_in_evidence: false',
    'account_identifier_recorded_in_evidence: false',
    'credential_or_worker_secret_recorded: false',
    'local_contract_is_hosted_evidence: false',
    'code_implies_provider_retention_approval: false',
  ]) {
    _expect(evidence, required, evidencePath);
  }
  for (final required in const [
    'status: review_pending_external_beta_blocked',
    'unknown_retention_treated_as_approved: false',
    'backup_restore_repopulates_deleted_account: false',
    'provider_claim_inferred_from_configuration: false',
  ]) {
    _expect(retention, required, retentionPath);
  }
  if (requireHosted || requireHostedOperations) {
    for (final required in const [
      'working_tree_clean_at_execution: true',
      'two_account_owner_isolation: passed',
      'correction_operator_resolution: passed',
      'consent_withdrawal_worker: passed',
      'deletion_worker_and_cancellation: passed',
      'fulfillment_receipt: passed',
    ]) {
      _expect(evidence, required, evidencePath);
    }
  }
  if (requireHostedOperations) {
    _expect(
      evidence,
      'status: hosted_fulfillment_verified_retention_pending',
      evidencePath,
    );
  }
  if (requireHosted) {
    for (final required in const [
      'status: hosted_fulfillment_and_retention_verified',
      'provider_retention_review: passed',
      'backup_expiry_and_restore_exclusion: passed',
    ]) {
      _expect(evidence, required, evidencePath);
    }
    for (final required in const [
      'status: approved',
      'product_owner_approval: approved',
      'legal_reviewer_approval: approved',
      'security_reviewer_approval: approved',
    ]) {
      _expect(retention, required, retentionPath);
    }
  }
  stdout.writeln(
    requireHosted
        ? 'Data Rights hosted fulfillment and retention drill passed.'
        : 'Data Rights local fulfillment contract passed; hosted evidence remains pending.',
  );
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing required evidence: $path');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

void _expect(String content, String snippet, String path) {
  if (!content.contains(snippet)) _fail('Missing "$snippet" in $path.');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
