import 'dart:io';

const evidencePath = 'docs/qst/INCIDENT_LIVE_DRILL.yaml';
const runnerPath = 'tools/qst/run_incident_live_drill.ps1';

void main(List<String> arguments) {
  final failures = <String>[];
  final evidence = _read(evidencePath, failures);
  final runner = _read(runnerPath, failures);
  final guard = _read('tools/qst/incident_control_guard.ps1', failures);
  for (final snippet in const [
    'exact_beta_project_required: true',
    'clean_candidate_required: true',
    'feature_state_restoration_required: true',
    'manual_receipt_is_not_inferred: true',
    'tabletop_is_live_execution_evidence: false',
    'open_s0_allows_distribution: false',
    'failed_restoration_allows_completion: false',
    'destructive_down_migration_executed: false',
    'raw_user_content_recorded: false',
    'credentials_recorded: false',
  ]) {
    _expect(evidence, snippet, evidencePath, failures);
  }
  for (final snippet in const [
    'Incident live drill requires a clean candidate worktree.',
    'ProjectRef does not match the reviewed Beta project.',
    'Invoke-GuardedPlanningPause',
    'New-IncidentControlFilter',
    'Resolve-IncidentTimeline',
    'Get-FileHash -Algorithm SHA256',
    'artifacts',
    'ConfirmNoDestructiveDatabaseRollback',
    'InputPreservationEvidenceRef',
    'ManualPathEvidenceRef',
  ]) {
    _expect(runner, snippet, runnerPath, failures);
  }
  for (final snippet in const [
    'Quest Planning must be enabled before the live pause drill.',
    'finally',
    'Quest Planning control restoration failed',
  ]) {
    _expect(guard, snippet, 'tools/qst/incident_control_guard.ps1', failures);
  }

  if (arguments.contains('--require-verified')) {
    final head = _command(['git', 'rev-parse', 'HEAD']).trim();
    final candidate = _read('docs/qst/BETA_CANDIDATE.yaml', failures);
    for (final snippet in [
      'status: verified',
      'candidate_source_commit: "$head"',
      'working_tree_clean_at_execution: true',
      '  executed: true',
      '  evidence_method: operator_attested_receipts',
      '  acknowledgement_within_one_hour: true',
      '  disabled_verified: true',
      '  restored_verified: true',
      '  rollback_launch_verified: true',
    ]) {
      _expect(evidence, snippet, evidencePath, failures);
    }
    for (final field in const [
      'release_manager_ref',
      'incident_owner_ref',
      'support_owner_ref',
      'evidence_ref',
      'communication_receipt_ref',
      'user_input_preservation_evidence_ref',
      'manual_path_evidence_ref',
      'run_id',
      'started_at_utc',
      'completed_at_utc',
      'stopped_at_utc',
      'detected_at_utc',
      'communicated_at_utc',
    ]) {
      if (_scalar(evidence, field) == null) failures.add('Missing $field.');
    }
    final detected = DateTime.tryParse(
      _scalar(evidence, 'detected_at_utc') ?? '',
    );
    final stopped = DateTime.tryParse(
      _scalar(evidence, 'stopped_at_utc') ?? '',
    );
    final acknowledged = DateTime.tryParse(
      _scalar(evidence, 'communicated_at_utc') ?? '',
    );
    if (detected == null ||
        stopped == null ||
        acknowledged == null ||
        !detected.isUtc ||
        !stopped.isUtc ||
        !acknowledged.isUtc ||
        detected.isAfter(stopped) ||
        stopped.isAfter(acknowledged) ||
        acknowledged.isAfter(DateTime.now().toUtc()) ||
        acknowledged.difference(detected) > const Duration(hours: 1)) {
      failures.add(
        'Receipt timestamps do not prove acknowledgement within one hour.',
      );
    }
    final rollback = _scalar(evidence, 'rollback_candidate_commit');
    if (rollback == null ||
        !candidate.contains('rollback_commit: "$rollback"')) {
      failures.add(
        'Incident rollback candidate is not in the candidate manifest.',
      );
    }
    if (RegExp(
      r'eyJ[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{30,}',
    ).hasMatch(evidence)) {
      failures.add('Incident evidence contains a possible credential.');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Incident live drill verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    arguments.contains('--require-verified')
        ? 'Incident live stop, pause, restoration, communication, and rollback evidence passed.'
        : 'Incident live drill contract is ready; external execution remains pending.',
  );
}

String? _scalar(String content, String field) {
  final value = RegExp(
    '^\\s*${RegExp.escape(field)}:\\s*"?([^"\\n]+)"?\\s*\$',
    multiLine: true,
  ).firstMatch(content)?.group(1)?.trim();
  return value == null || value == 'null' || value == 'pending' ? null : value;
}

String _read(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing $path');
    return '';
  }
  return file.readAsStringSync();
}

String _command(List<String> command) {
  final result = Process.runSync(command.first, command.skip(1).toList());
  if (result.exitCode != 0) {
    stderr.writeln(result.stderr);
    exit(1);
  }
  return result.stdout.toString();
}

void _expect(
  String content,
  String snippet,
  String path,
  List<String> failures,
) {
  if (!content.contains(snippet)) failures.add('$path missing: $snippet');
}
