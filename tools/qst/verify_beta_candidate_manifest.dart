import 'dart:io';

const generatorPath = 'tools/qst/generate_beta_candidate_manifest.dart';
const manifestPath = 'docs/qst/BETA_CANDIDATE.yaml';

const requiredGeneratorSnippets = [
  'worktree_clean_before_manifest',
  'latestLocalMigration',
  'flutterTestFileCount',
  'externalEvidenceComplete',
  'approved_requires_artifact_checksum',
  'certutil',
  'sha256sum',
];

const requiredManifestSnippets = [
  'candidate_status: "draft"',
  'distribution_ready: false',
  'app_version: "1.0.0+1"',
  'source_commit:',
  'rollback_commit:',
  'inventory:',
  'latest_local_migration:',
  'remote_migration_head:',
  'edge_function_count:',
  'flutter_test_file_count:',
  'automated_gates:',
  'flutter_tests:',
  'external_evidence:',
  'status: "evidence_missing"',
  'artifacts:',
  'status: not_built',
  'local_fallback_is_cloud_evidence: false',
];

void main() {
  final failures = <String>[];
  _checkFile(generatorPath, requiredGeneratorSnippets, failures);
  _checkFile(manifestPath, requiredManifestSnippets, failures);
  _checkInventory(failures);

  if (failures.isNotEmpty) {
    stderr.writeln('Beta candidate manifest verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Beta candidate manifest verification passed.');
  stdout.writeln('Candidate is draft and not distribution-ready.');
}

void _checkInventory(List<String> failures) {
  final migrations =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .map((file) => file.uri.pathSegments.last)
          .toList()
        ..sort();
  final testCount = Directory('apps/mobile/test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_test.dart'))
      .length;
  final content = File(manifestPath).readAsStringSync();
  final approved =
      content.contains('candidate_status: "approved"') ||
      content.contains('distribution_ready: true');
  if (approved && !content.contains('flutter_tests: "passed"')) {
    failures.add('Approved candidate requires passed Flutter tests.');
  }
  if (migrations.isEmpty ||
      !content.contains('latest_local_migration: "${migrations.last}"')) {
    failures.add('Manifest latest_local_migration is stale.');
  }
  if (!content.contains('flutter_test_file_count: $testCount')) {
    failures.add('Manifest flutter_test_file_count is stale.');
  }
}

void _checkFile(String path, List<String> snippets, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing required file: $path');
    return;
  }
  final content = file.readAsStringSync();
  for (final snippet in snippets) {
    if (!content.contains(snippet)) {
      failures.add('Missing "$snippet" in $path');
    }
  }
}
