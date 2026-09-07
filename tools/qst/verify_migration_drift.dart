import 'dart:io';

const migrationDirectory = 'supabase/migrations';
const driftPath = 'docs/qst/SUPABASE_MIGRATION_DRIFT.yaml';
const evidencePaths = <String>[
  'docs/qst/BETA_SUPABASE_PROJECT.yaml',
  'docs/qst/BETA_RLS_EVIDENCE.yaml',
  'docs/qst/BETA_CANDIDATE.yaml',
  'docs/qst/HOSTED_EVIDENCE_RUN.yaml',
  'docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml',
];

void main() {
  final failures = <String>[];
  final migrations =
      Directory(migrationDirectory)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .map((file) => file.uri.pathSegments.last)
          .toList()
        ..sort();
  if (migrations.isEmpty) failures.add('No migrations found.');
  final latest = migrations.isEmpty ? '' : migrations.last;

  final driftFile = File(driftPath);
  if (!driftFile.existsSync()) {
    failures.add('Missing $driftPath');
  } else {
    final drift = driftFile.readAsStringSync();
    final remote = _quotedValue(drift, 'remote_head');
    final declaredLatest = _quotedValue(drift, 'latest_local');
    if (declaredLatest != latest) {
      failures.add(
        'Drift manifest latest_local is $declaredLatest, expected $latest.',
      );
    }
    if (!migrations.contains(remote)) {
      failures.add('Remote head is not present locally: $remote');
    } else {
      final pending = migrations
          .where((name) => name.compareTo(remote) > 0)
          .length;
      final declaredPending = _integerValue(drift, 'pending_migration_count');
      if (declaredPending != pending) {
        failures.add(
          'pending_migration_count is $declaredPending, expected $pending.',
        );
      }
    }
  }

  for (final path in evidencePaths) {
    final file = File(path);
    if (!file.existsSync()) {
      failures.add('Missing evidence document: $path');
      continue;
    }
    if (!file.readAsStringSync().contains(latest)) {
      failures.add('$path does not reference latest local migration $latest.');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Migration drift verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln('Migration drift verification passed.');
  stdout.writeln(
    'Latest local migration: $latest; evidence documents: ${evidencePaths.length}.',
  );
}

String _quotedValue(String yaml, String key) =>
    RegExp('^$key:\\s*"([^"]+)"', multiLine: true).firstMatch(yaml)?.group(1) ??
    '';

int _integerValue(String yaml, String key) =>
    int.tryParse(
      RegExp('^$key:\\s*(\\d+)', multiLine: true).firstMatch(yaml)?.group(1) ??
          '',
    ) ??
    -1;
