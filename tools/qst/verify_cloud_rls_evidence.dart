import 'dart:io';

const evidencePath = 'docs/qst/BETA_RLS_EVIDENCE.yaml';
const projectEvidencePath = 'docs/qst/BETA_SUPABASE_PROJECT.yaml';
const testPath = 'supabase/tests/rls_behavior.sql';
const runnerPath = 'tools/qst/run_rls_behavior_tests.ps1';
const capturePath = 'tools/qst/capture_cloud_rls_evidence.ps1';
const runbookPath = 'docs/product/cloud_migration_rls_evidence.md';

const guardrails = [
  'database_url_recorded: false',
  'database_password_recorded: false',
  'private_journey_content_recorded: false',
  'local_database_is_cloud_evidence: false',
  'requires_verified_supabase_project: true',
];

Future<void> main(List<String> arguments) async {
  final requireCloud = arguments.contains('--require-cloud');
  final failures = <String>[];
  final evidence = _read(evidencePath, failures);
  final projectEvidence = _read(projectEvidencePath, failures);
  final test = _read(testPath, failures);
  final runner = _read(runnerPath, failures);
  final capture = _read(capturePath, failures);
  final runbook = _read(runbookPath, failures);

  for (final guardrail in guardrails) {
    _expect(evidence, guardrail, evidencePath, failures);
  }
  for (final snippet in [
    r'$env:PGPASSWORD = $databasePassword',
    r'$env:PGSSLMODE = $sslMode',
    "[switch]\$ValidateOnly",
    "[switch]\$LinkedCli",
    'db query --linked',
    'Unsupported psql metacommand remains',
    '--host',
    '--username',
    '-v ON_ERROR_STOP=1',
  ]) {
    _expect(runner, snippet, runnerPath, failures);
  }
  if (runner.contains(r'psql $DatabaseUrl')) {
    failures.add('Database URL must not be passed directly to psql.');
  }
  for (final snippet in [
    "'migration', 'list', '--linked'",
    'QST-041 RLS behavior tests passed',
    'Get-FileHash -Algorithm SHA256',
    'status: verified',
  ]) {
    _expect(capture, snippet, capturePath, failures);
  }
  for (final snippet in [
    'begin;',
    'rollback;',
    'owner cannot read another private Quest',
    'other cannot read owner Arc Memory',
    'other cannot create a Quest for owner',
  ]) {
    _expect(test, snippet, testPath, failures);
  }
  for (final snippet in [
    'SUPABASE_DB_URL',
    '-LinkedCli',
    'db query --linked',
    'transaction',
    '--require-cloud',
  ]) {
    _expect(runbook, snippet, runbookPath, failures);
  }

  _rejectSecrets(evidence, failures);
  if (requireCloud) {
    await _verifyCloud(evidence, projectEvidence, test, failures);
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Cloud migration and RLS evidence verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Cloud migration and RLS evidence verification passed.');
  stdout.writeln(
    requireCloud
        ? 'Cloud migration and database-backed RLS evidence are verified.'
        : 'Secure RLS evidence contract is ready; cloud execution is separate.',
  );
}

Future<void> _verifyCloud(
  String evidence,
  String projectEvidence,
  String test,
  List<String> failures,
) async {
  if (!RegExp(r'^status: verified$', multiLine: true).hasMatch(evidence)) {
    failures.add('Top-level RLS evidence status must be verified.');
  }
  if (!RegExp(
    r'^status: verified$',
    multiLine: true,
  ).hasMatch(projectEvidence)) {
    failures.add('QST-160 Supabase project evidence must be verified first.');
  }

  final projectRef = _scalar(evidence, 'project_ref', 0);
  final projectEvidenceRef = _scalar(projectEvidence, 'ref', 2);
  if (projectRef == null || !RegExp(r'^[a-z0-9]{20}$').hasMatch(projectRef)) {
    failures.add('A 20-character project ref is required in RLS evidence.');
  } else if (projectRef != projectEvidenceRef) {
    failures.add('RLS and QST-160 project refs do not match.');
  }

  final commit = _scalar(evidence, 'candidate_source_commit', 0);
  if (commit == null || !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
    failures.add('A full candidate source commit is required.');
  }
  _expect(evidence, 'migrations:\n  status: applied', evidencePath, failures);
  _expect(evidence, 'rls_behavior:\n  status: passed', evidencePath, failures);

  final migrations =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  if (migrations.isEmpty) {
    failures.add('No migration files found.');
  } else {
    final latest = migrations.last.uri.pathSegments.last;
    _expect(evidence, 'remote_head: "$latest"', evidencePath, failures);
  }

  final expectedAssertions = RegExp(
    r'select\s+(?:pg_temp\.)?qst_assert_(?:eq|raises)\s*\(',
    caseSensitive: false,
  ).allMatches(test).length;
  if (_scalar(evidence, 'assertion_count', 2) != '$expectedAssertions') {
    failures.add('RLS assertion count does not match the current test file.');
  }
  final hash = _scalar(evidence, 'test_sha256', 2);
  final currentHash = await _sha256(testPath);
  if (hash == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
    failures.add('A SHA-256 for the executed RLS test file is required.');
  } else if (currentHash == null || hash != currentHash) {
    failures.add('RLS test SHA-256 does not match the current test file.');
  }
  for (final result in [
    'owner_checks: passed',
    'cross_account_checks: passed',
    'write_denial_checks: passed',
    'transaction_rolled_back: true',
  ]) {
    _expect(evidence, result, evidencePath, failures);
  }
  for (final field in ['executed_at_utc', 'psql_version']) {
    if (_scalar(evidence, field, 2) == null) {
      failures.add('RLS evidence field is missing: $field');
    }
  }
}

Future<String?> _sha256(String path) async {
  final command = Platform.isWindows ? 'certutil' : 'sha256sum';
  final arguments = Platform.isWindows ? ['-hashfile', path, 'SHA256'] : [path];
  final result = await Process.run(command, arguments);
  if (result.exitCode != 0) {
    return null;
  }
  return RegExp(
    r'\b[a-fA-F0-9]{64}\b',
  ).firstMatch(result.stdout as String)?.group(0)?.toLowerCase();
}

void _rejectSecrets(String evidence, List<String> failures) {
  final patterns = [
    RegExp(r'postgres(?:ql)?://\S+', caseSensitive: false),
    RegExp(r'password\s*[:=]\s*\S{8,}', caseSensitive: false),
    RegExp(r'eyJ[A-Za-z0-9_-]{20,}'),
  ];
  for (final pattern in patterns) {
    if (pattern.hasMatch(evidence)) {
      failures.add('Possible database secret found in $evidencePath.');
    }
  }
}

String? _scalar(String content, String field, int indent) {
  final prefix = ' ' * indent;
  final match = RegExp(
    '^${RegExp.escape(prefix + field)}:\\s*(.*?)\\s*\$',
    multiLine: true,
  ).firstMatch(content);
  var value = match?.group(1)?.trim();
  if (value == null || value.isEmpty || value == 'null' || value == '""') {
    return null;
  }
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    value = value.substring(1, value.length - 1);
  }
  return value.isEmpty ? null : value;
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
  if (!content.contains(snippet)) {
    failures.add('Missing "$snippet" in $path.');
  }
}
