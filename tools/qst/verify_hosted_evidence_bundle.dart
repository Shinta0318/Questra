import 'dart:io';

const runPath = 'docs/qst/HOSTED_EVIDENCE_RUN.yaml';
const projectPath = 'docs/qst/BETA_SUPABASE_PROJECT.yaml';
const rlsPath = 'docs/qst/BETA_RLS_EVIDENCE.yaml';
const dualPath = 'docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml';
const runnerPath = 'tools/qst/run_hosted_evidence_gate.ps1';

void main(List<String> arguments) {
  final requireCloud = arguments.contains('--require-cloud');
  final expectedShaArgument = arguments
      .where((value) => value.startsWith('--expected-sha='))
      .firstOrNull;
  final expectedSha = expectedShaArgument?.substring('--expected-sha='.length);
  final failures = <String>[];
  final run = _read(runPath, failures);
  final project = _read(projectPath, failures);
  final rls = _read(rlsPath, failures);
  final dual = _read(dualPath, failures);
  final runner = _read(runnerPath, failures);

  for (final snippet in [
    'Hosted evidence must start from a clean candidate working tree.',
    'bootstrap_supabase_beta.ps1',
    'capture_cloud_rls_evidence.ps1',
    'run_qst199_cloud_acceptance.ps1',
    'verify_supabase_beta_bootstrap.dart --require-cloud',
    'verify_cloud_rls_evidence.dart --require-cloud',
    'verify_dual_account_persistence.dart --require-cloud',
    'verify_hosted_evidence_runner_v2.dart',
    'run_data_rights_hosted_drill.ps1',
    'run_observability_hosted_drill.ps1',
    'data_rights_fulfillment: passed_retention_review_pending',
    'runtime_observability: passed',
    '--expected-sha=',
  ]) {
    _expect(runner, snippet, runnerPath, failures);
  }
  for (final guardrail in [
    'credential_values_recorded: false',
    'account_identifiers_recorded: false',
    'private_journey_content_recorded: false',
    'local_fallback_is_cloud_evidence: false',
  ]) {
    _expect(run, guardrail, runPath, failures);
  }
  _rejectSecrets(run, failures);

  if (requireCloud) {
    _expect(run, 'status: verified', runPath, failures);
    _expect(run, 'working_tree_clean_at_start: true', runPath, failures);
    for (final result in [
      'migrations_and_functions: passed',
      'rls_behavior: passed',
      'dual_account_journey: passed',
      'data_export_owner_scope: passed',
      'correction_owner_scope: passed',
      'consent_withdrawal: passed',
      'ephemeral_accounts_removed: passed',
      'runtime_observability: passed',
    ]) {
      _expect(run, result, runPath, failures);
    }
    final commits = <String?>{
      _scalar(run, 'candidate_source_commit', 0),
      _scalar(project, 'candidate_source_commit', 0),
      _scalar(rls, 'source_commit_at_execution', 0),
      _scalar(dual, 'source_commit_at_execution', 0),
    };
    if (commits.length != 1 ||
        commits.single == null ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(commits.single!)) {
      failures.add('Hosted evidence does not share one candidate SHA.');
    } else if (expectedSha != null && commits.single != expectedSha) {
      failures.add('Hosted evidence SHA does not match --expected-sha.');
    }
    _expect(
      project,
      'working_tree_clean_at_deploy: true',
      projectPath,
      failures,
    );
    _expect(rls, 'working_tree_clean_at_execution: true', rlsPath, failures);
    _expect(dual, 'working_tree_clean_at_execution: true', dualPath, failures);
    final projectRefs = <String?>{
      _scalar(run, 'project_ref', 0),
      _scalar(project, 'ref', 2),
      _scalar(rls, 'project_ref', 0),
      _scalar(dual, 'project_ref', 0),
    };
    if (projectRefs.length != 1 ||
        projectRefs.single == null ||
        !RegExp(r'^[a-z0-9]{20}$').hasMatch(projectRefs.single!)) {
      failures.add('Hosted evidence does not share one project ref.');
    }
    final latest = _latestMigration();
    if (latest == null) {
      failures.add('No local migration exists.');
    } else {
      _expect(run, 'latest_migration: "$latest"', runPath, failures);
      _expect(project, 'remote_head: "$latest"', projectPath, failures);
      _expect(rls, 'remote_head: "$latest"', rlsPath, failures);
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Hosted evidence bundle verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    requireCloud
        ? 'Hosted evidence bundle verification passed.'
        : 'Hosted evidence automation contract is ready; cloud execution is pending.',
  );
}

String? _latestMigration() {
  final files =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files.isEmpty ? null : files.last.uri.pathSegments.last;
}

void _rejectSecrets(String content, List<String> failures) {
  for (final pattern in [
    RegExp(r'eyJ[A-Za-z0-9_-]{20,}'),
    RegExp(r'postgres(?:ql)?://\S+', caseSensitive: false),
    RegExp(r'password\s*[:=]\s*\S+', caseSensitive: false),
    RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
  ]) {
    if (pattern.hasMatch(content)) failures.add('Possible secret in $runPath.');
  }
}

String? _scalar(String content, String field, int indent) {
  final match = RegExp(
    '^${RegExp.escape('${' ' * indent}$field')}:\\s*"?([^"\\s]+)"?\\s*\$',
    multiLine: true,
  ).firstMatch(content);
  final value = match?.group(1);
  return value == null || value == 'null' ? null : value;
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
