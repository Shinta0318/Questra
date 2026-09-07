import 'dart:io';

const outputPath = 'docs/qst/DATA_RIGHTS_FULFILLMENT_DRILL.yaml';

void main() {
  final migration = File(
    'supabase/migrations/202608250007_data_rights_fulfillment_sla.sql',
  ).readAsStringSync();
  final worker = File(
    'supabase/functions/process-data-rights-requests/index.ts',
  ).readAsStringSync();
  final receiptStart = migration.indexOf(
    'create table if not exists public.data_rights_fulfillment_receipts',
  );
  final receiptEnd = migration.indexOf(
    'alter table public.data_rights_fulfillment_receipts',
    receiptStart,
  );
  final receiptSchema = receiptStart >= 0 && receiptEnd > receiptStart
      ? migration.substring(receiptStart, receiptEnd)
      : '';
  final sha = _command(['git', 'rev-parse', 'HEAD']).trim();
  final clean = _command(['git', 'status', '--porcelain']).trim().isEmpty;
  final checks = <String, bool>{
    'correction_sla_contract': _all(migration, [
      "else interval '30 days'",
      'claim_pending_correction_requests',
      'resolve_data_correction_request',
    ]),
    'correction_resolution_allowlist': migration.contains(
      "'applied', 'no_change_required', 'identity_unverified', 'unsupported'",
    ),
    'withdrawal_transaction_contract': _all(migration, [
      'fulfill_pending_consent_withdrawals',
      "status = 'withdrawn'",
      'delete from public.business_quest_signals',
    ]),
    'deletion_cancellation_window': _all(
      File(
        'supabase/migrations/202608090004_data_rights_reauthentication_worker.sql',
      ).readAsStringSync(),
      ["now() + interval '72 hours'", 'cancel_my_data_rights_request'],
    ),
    'deletion_retry_classification': _all(worker, [
      'classifyWorkerError',
      'rate_limited',
      'provider_failure',
    ]),
    'content_free_fulfillment_receipt':
        receiptSchema.contains('resolution_code text not null') &&
        !RegExp(
          r'\b(owner_id|content|email|phone)\b',
          caseSensitive: false,
        ).hasMatch(receiptSchema),
    'aggregate_metrics_only': _all(migration, [
      'get_data_rights_fulfillment_metrics',
      "'pending', count(*)",
      "'overdue', count(*)",
    ]),
    'worker_response_has_no_request_id':
        !worker.contains('results.push') &&
        _all(worker, [
          'consent_withdrawals_completed:',
          'account_deletions_claimed:',
          'account_deletions_completed:',
          'account_deletions_retry_scheduled:',
        ]),
  };
  if (checks.values.any((passed) => !passed)) {
    stderr.writeln('Data Rights local drill contract failed:');
    for (final entry in checks.entries.where((entry) => !entry.value)) {
      stderr.writeln('- ${entry.key}');
    }
    exit(1);
  }

  final content = StringBuffer()
    ..writeln('version: 1')
    ..writeln('qst: QST-368')
    ..writeln('status: local_contract_passed_hosted_pending')
    ..writeln('generated_at_utc: "${DateTime.now().toUtc().toIso8601String()}"')
    ..writeln('candidate_source_commit: "$sha"')
    ..writeln('working_tree_clean_at_execution: $clean')
    ..writeln('latest_migration: "${_latestMigration()}"')
    ..writeln('local_checks:');
  for (final entry in checks.entries) {
    content.writeln('  ${entry.key}: ${entry.value ? 'passed' : 'failed'}');
  }
  content
    ..writeln('hosted_checks:')
    ..writeln('  two_account_owner_isolation: pending')
    ..writeln('  correction_operator_resolution: pending')
    ..writeln('  consent_withdrawal_worker: pending')
    ..writeln('  deletion_worker_and_cancellation: pending')
    ..writeln('  fulfillment_receipt: pending')
    ..writeln('  provider_retention_review: pending')
    ..writeln('  backup_expiry_and_restore_exclusion: pending')
    ..writeln('guardrails:')
    ..writeln('  request_content_recorded_in_evidence: false')
    ..writeln('  account_identifier_recorded_in_evidence: false')
    ..writeln('  credential_or_worker_secret_recorded: false')
    ..writeln('  local_contract_is_hosted_evidence: false')
    ..writeln('  code_implies_provider_retention_approval: false')
    ..writeln('  deletion_bypasses_cancellation_window: false');
  File(outputPath).writeAsStringSync(content.toString());
  stdout.writeln(
    'Data Rights local fulfillment drill passed; hosted evidence pending.',
  );
}

bool _all(String content, List<String> snippets) =>
    snippets.every(content.contains);

String _latestMigration() {
  final files =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .map((file) => file.uri.pathSegments.last)
          .toList()
        ..sort();
  return files.last;
}

String _command(List<String> command) {
  final result = Process.runSync(command.first, command.skip(1).toList());
  if (result.exitCode != 0) throw StateError(result.stderr as String);
  return result.stdout as String;
}
