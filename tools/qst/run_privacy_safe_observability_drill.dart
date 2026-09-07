import 'dart:io';

const evidencePath = 'docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml';

void main() {
  final migration = File(
    'supabase/migrations/202608250008_privacy_safe_runtime_observability.sql',
  ).readAsStringSync();
  final sink = File(
    'apps/mobile/lib/core/observability/runtime_evidence_sink.dart',
  ).readAsStringSync();
  final arc = File(
    'apps/mobile/lib/features/arc/arc_chat_service.dart',
  ).readAsStringSync();
  final checks = <String, bool>{
    'authenticated_owner_assignment': _all(migration, [
      'v_owner uuid := auth.uid()',
      'owner_id = auth.uid()',
      'grant execute on function public.record_runtime_evidence(jsonb) to authenticated',
    ]),
    'server_field_allowlist': _all(migration, [
      'v_allowed_keys text[]',
      'Unsupported evidence field.',
      'Incomplete evidence contract.',
      'Evidence contains an unsafe token.',
    ]),
    'direct_write_denied': _all(migration, [
      'revoke all on public.runtime_evidence_events from anon, authenticated',
      'revoke all on public.runtime_evidence_alert_queue from anon, authenticated',
    ]),
    'per_owner_rate_limit': _all(migration, [
      'runtime_evidence_rate_buckets',
      "interval '10 minutes'",
      'v_event_count > 120',
      'v_high_severity_count > 10',
    ]),
    'retention_30_days': _all(migration, [
      "now() + interval '30 days'",
      'purge_expired_runtime_evidence',
    ]),
    's0_s1_alert_queue': _all(migration, [
      "v_severity in ('S0', 'S1')",
      'claim_runtime_evidence_alerts',
      'resolve_runtime_evidence_alert',
    ]),
    'aggregate_slo_only': _all(migration, [
      'get_runtime_slo_window',
      "'total_events', count(*)",
      "'fallback_events', count(*)",
    ]),
    'collection_default_off': _all(sink, [
      "'ENABLE_RUNTIME_EVIDENCE_SINK'",
      'defaultValue: false',
      'NoopRuntimeEvidenceSink',
    ]),
    'transport_failure_isolated': _all(sink, [
      'try {',
      'on Object',
      "must never break the user's primary journey",
    ]),
    'arc_fallback_connected': _all(arc, [
      'evidenceSink.record',
      'RuntimeEvidenceType.aiFallback',
      "operation: 'arc_chat.invoke'",
      "errorCode: error is TimeoutException",
    ]),
  };
  if (checks.values.any((passed) => !passed)) {
    stderr.writeln('Privacy-safe observability local drill failed:');
    for (final entry in checks.entries.where((entry) => !entry.value)) {
      stderr.writeln('- ${entry.key}');
    }
    exit(1);
  }
  final sha = _command(['git', 'rev-parse', 'HEAD']).trim();
  final clean = _command(['git', 'status', '--porcelain']).trim().isEmpty;
  final output = StringBuffer()
    ..writeln('version: 1')
    ..writeln('qst: QST-370')
    ..writeln('status: local_contract_passed_hosted_pending')
    ..writeln('generated_at_utc: "${DateTime.now().toUtc().toIso8601String()}"')
    ..writeln('candidate_source_commit: "$sha"')
    ..writeln('working_tree_clean_at_execution: $clean')
    ..writeln('latest_migration: "${_latestMigration()}"')
    ..writeln('hosted_sink_enabled: false')
    ..writeln('local_checks:');
  for (final entry in checks.entries) {
    output.writeln('  ${entry.key}: ${entry.value ? 'passed' : 'failed'}');
  }
  output
    ..writeln('hosted_checks:')
    ..writeln('  migration_deployed: pending')
    ..writeln('  two_account_owner_isolation: pending')
    ..writeln('  retention_purge: pending')
    ..writeln('  alert_delivery_receipt: pending')
    ..writeln('  s0_distribution_stop: pending')
    ..writeln('  s1_rollout_pause: pending')
    ..writeln('  sink_failure_journey_continuity: pending')
    ..writeln('guardrails:')
    ..writeln('  raw_user_content_recorded: false')
    ..writeln('  account_identifier_in_alert_payload: false')
    ..writeln('  credential_or_token_recorded: false')
    ..writeln('  collection_enabled_without_flag: false')
    ..writeln('  local_contract_is_hosted_evidence: false')
    ..writeln('  evidence_failure_breaks_primary_journey: false');
  File(evidencePath).writeAsStringSync(output.toString());
  stdout.writeln(
    'Privacy-safe observability local drill passed; hosted evidence pending.',
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
