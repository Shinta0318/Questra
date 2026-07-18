import 'dart:io';

const generatorPath = 'tools/qst/generate_beta_candidate_manifest.dart';
const manifestPath = 'docs/qst/BETA_CANDIDATE.yaml';

const requiredGeneratorSnippets = [
  'worktree_clean_before_manifest',
  'externalEvidenceComplete',
  'approved_requires_artifact_checksum',
  'certutil',
  'sha256sum',
];

const requiredManifestSnippets = [
  'candidate_status: "validated"',
  'distribution_ready: false',
  'app_version: "1.0.0+1"',
  'source_commit:',
  'rollback_commit:',
  'automated_gates:',
  'flutter_tests: "passed"',
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

  if (failures.isNotEmpty) {
    stderr.writeln('Beta candidate manifest verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Beta candidate manifest verification passed.');
  stdout.writeln('Candidate is validated but not distribution-ready.');
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
