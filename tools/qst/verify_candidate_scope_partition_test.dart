import 'verify_candidate_scope_partition.dart';

void main() {
  const expected = <String, String>{
    'README.md': 'product_governance',
    'apps/mobile/pubspec.lock': 'mobile_runtime',
    'supabase/config.toml': 'supabase_runtime',
    'apps/mobile/lib/main.dart': 'mobile_runtime',
    'apps/mobile/test/widget_test.dart': 'mobile_tests',
    'supabase/migrations/example.sql': 'supabase_runtime',
    '.github/workflows/release-gate.yml': 'release_automation',
    'docs/qst/BACKLOG.yaml': 'qst_governance',
  };
  for (final entry in expected.entries) {
    final actual = candidateScopeMatches(entry.key);
    if (actual.length != 1 || actual.single != entry.value) {
      throw StateError('Incorrect candidate scope for ${entry.key}: $actual');
    }
  }
  if (candidateScopeMatches('private.env').isNotEmpty) {
    throw StateError('Unknown paths must remain unclassified.');
  }
  print('Candidate scope partition fixtures: PASS (${expected.length} paths).');
}
