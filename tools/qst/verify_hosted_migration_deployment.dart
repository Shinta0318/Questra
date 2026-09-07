import 'dart:io';

const evidencePath = 'docs/qst/HOSTED_MIGRATION_DEPLOYMENT.yaml';
const driftPath = 'docs/qst/SUPABASE_MIGRATION_DRIFT.yaml';
const runnerPath = 'tools/qst/run_hosted_migration_deployment.ps1';

void main(List<String> arguments) {
  final failures = <String>[];
  final evidence = _read(evidencePath, failures);
  final drift = _read(driftPath, failures);
  final runner = _read(runnerPath, failures);
  final migrations =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .map((file) => file.uri.pathSegments.last)
          .toList()
        ..sort();

  if (migrations.isEmpty) {
    failures.add('No local migrations found.');
  } else {
    final latest = migrations.last;
    final remoteHead = _scalar(drift, 'remote_head');
    if (remoteHead == null || !migrations.contains(remoteHead)) {
      failures.add('Drift remote head is missing from local migrations.');
    } else {
      final pending = migrations
          .skip(migrations.indexOf(remoteHead) + 1)
          .toList();
      _expect(evidence, 'remote_head_before: "$remoteHead"', failures);
      _expect(evidence, 'latest_local: "$latest"', failures);
      _expect(evidence, 'pending_at_plan: ${pending.length}', failures);
      for (final migration in pending) {
        _expect(evidence, '    - "$migration"', failures);
      }
      final declared = RegExp(
        r'^    - "([0-9]{12,14}_[^"]+\.sql)"$',
        multiLine: true,
      ).allMatches(evidence).map((match) => match.group(1)!).toList();
      if (declared.length != pending.length || !_sameItems(declared, pending)) {
        failures.add(
          'Pending migration plan does not exactly match local drift.',
        );
      }
    }
  }

  for (final snippet in [
    '[switch]\$Execute',
    'ConfirmProjectRef',
    'Candidate SHA does not match HEAD.',
    'Hosted migration deployment requires a clean worktree.',
    'Linked Supabase project does not match the requested project.',
    "'db', 'push', '--linked', '--dry-run'",
    "'db', 'push', '--linked'",
    "'migration', 'list', '--linked'",
    'Unexpected hosted migration head',
    'destructive repair is intentionally unsupported',
    'HOSTED_MIGRATION_DEPLOYMENT.yaml',
  ]) {
    if (!runner.contains(snippet)) {
      failures.add('Runner missing: $snippet');
    }
  }
  for (final guardrail in [
    'destructive_repair_allowed: false',
    'secret_values_recorded: false',
    'local_plan_is_hosted_evidence: false',
    'unexpected_remote_head_allows_push: false',
  ]) {
    _expect(evidence, guardrail, failures);
  }

  final requireCloud = arguments.contains('--require-cloud');
  if (requireCloud) {
    _expect(evidence, 'status: verified', failures);
    _expect(evidence, 'working_tree_clean_at_execution: true', failures);
    if (migrations.isNotEmpty) {
      _expect(evidence, 'remote_head_after: "${migrations.last}"', failures);
    }
    final sha = _scalar(evidence, 'candidate_source_commit');
    if (sha == null || !RegExp(r'^[a-f0-9]{40}$').hasMatch(sha)) {
      failures.add('Verified deployment requires a candidate SHA.');
    }
    final digest = _scalar(evidence, 'migration_list_sha256', indent: 2);
    if (digest == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      failures.add('Verified deployment requires migration-list SHA-256.');
    }
    for (final field in ['executed_at_utc', 'cli_version']) {
      if (_scalar(evidence, field) == null) {
        failures.add('Verified deployment field is missing: $field');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Hosted migration deployment verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }
  stdout.writeln(
    requireCloud
        ? 'Hosted migration deployment evidence is verified.'
        : 'Hosted migration deployment plan is consistent; execution remains external.',
  );
}

bool _sameItems(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _read(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing $path');
    return '';
  }
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

String? _scalar(String content, String field, {int indent = 0}) {
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
  return value;
}

void _expect(String content, String snippet, List<String> failures) {
  if (!content.contains(snippet)) failures.add('Missing: $snippet');
}
