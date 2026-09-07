import 'dart:io';

const migrationDirectory = 'supabase/migrations';
const manifestPath = 'docs/qst/RLS_COVERAGE_MANIFEST.yaml';

void main() {
  final failures = <String>[];
  final sql = Directory(migrationDirectory)
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .map((file) => file.readAsStringSync())
      .join('\n')
      .toLowerCase();

  final created = _captures(
    sql,
    RegExp(r'create\s+table\s+(?:if\s+not\s+exists\s+)?public\.([a-z0-9_]+)'),
  );
  final rlsEnabled = _captures(
    sql,
    RegExp(
      r'alter\s+table\s+public\.([a-z0-9_]+)\s+enable\s+row\s+level\s+security',
    ),
  );
  final policyTables = _captures(
    sql,
    RegExp(r'create\s+policy\s+[^;]+?\s+on\s+public\.([a-z0-9_]+)'),
  );
  final explicitlyRestricted = <String>{};
  for (final match in RegExp(
    r'revoke\s+all\s+on(?:\s+table)?\s+([\s\S]*?)\s+from\s+(?:anon|authenticated|public)',
  ).allMatches(sql)) {
    explicitlyRestricted.addAll(
      _captures(match.group(1) ?? '', RegExp(r'public\.([a-z0-9_]+)')),
    );
  }

  final missingRls = created.difference(rlsEnabled).toList()..sort();
  final missingAccessContract =
      created.difference(policyTables.union(explicitlyRestricted)).toList()
        ..sort();
  for (final table in missingRls)
    failures.add('RLS not enabled: public.$table');
  for (final table in missingAccessContract) {
    failures.add('No policy or explicit revoke contract: public.$table');
  }

  final manifest = File(manifestPath);
  if (!manifest.existsSync()) {
    failures.add('Missing $manifestPath');
  } else {
    final text = manifest.readAsStringSync();
    if (_integerValue(text, 'public_tables_created') != created.length) {
      failures.add('Manifest public table count is stale.');
    }
    if (_integerValue(text, 'rls_enabled') != rlsEnabled.length) {
      failures.add('Manifest RLS table count is stale.');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Dynamic RLS coverage verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln('Dynamic RLS coverage verification passed.');
  stdout.writeln(
    'Derived ${created.length} public tables; all enable RLS and declare policy or explicit revoke access.',
  );
}

Set<String> _captures(String input, RegExp pattern) =>
    pattern.allMatches(input).map((match) => match.group(1)!).toSet();

int _integerValue(String yaml, String key) =>
    int.tryParse(
      RegExp(
            '^\\s*$key:\\s*(\\d+)',
            multiLine: true,
          ).firstMatch(yaml)?.group(1) ??
          '',
    ) ??
    -1;
