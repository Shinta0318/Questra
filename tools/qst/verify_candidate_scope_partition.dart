import 'dart:io';

import 'candidate_git_state.dart';

const manifestPath = 'docs/qst/CANDIDATE_SCOPE_PARTITION.yaml';
const expectedBranch = 'codex/initial-questra-structure-pr';

const scopeGroups = <String, List<String>>{
  'mobile_runtime': [
    'apps/mobile/lib/',
    'apps/mobile/pubspec.yaml',
    'apps/mobile/web/',
  ],
  'mobile_tests': ['apps/mobile/test/', 'apps/mobile/integration_test/'],
  'supabase_runtime': [
    'supabase/functions/',
    'supabase/migrations/',
    'supabase/tests/',
  ],
  'release_automation': ['.gitignore', '.github/', 'tools/qst/'],
  'product_governance': ['docs/analytics/', 'docs/legal/', 'docs/product/'],
  'qst_governance': ['docs/qst/', 'reports/qst/'],
};

const postCandidateEvidenceOutputs = <String>{
  'docs/qst/BETA_CANDIDATE.yaml',
  'docs/qst/HOSTED_EVIDENCE_RUN.yaml',
  'docs/qst/HOSTED_MIGRATION_DEPLOYMENT.yaml',
  'docs/qst/DATA_RIGHTS_FULFILLMENT_DRILL.yaml',
  'docs/qst/RUNTIME_SLO_DRILL.yaml',
  'docs/qst/OBSERVABILITY_SINK_EVIDENCE.yaml',
  'docs/qst/PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml',
  'docs/qst/WEB_CANDIDATE_SESSION.yaml',
  'docs/qst/ANDROID_CANDIDATE_SESSION.yaml',
  'docs/qst/LEGAL_SIGNOFF_INTAKE.yaml',
  'docs/qst/BETA_LEGAL_SIGNOFF.yaml',
  'docs/qst/LEGAL_VERSION_RECONCILIATION.yaml',
  'docs/qst/DEPENDENCY_LICENSE_MANIFEST.yaml',
  'docs/legal/THIRD_PARTY_NOTICES.md',
  'docs/qst/CANDIDATE_ASSET_PACKAGE.yaml',
  'docs/qst/ARC_ASSET_RELEASE_DECISION.yaml',
  'docs/qst/BETA_FEEDBACK_OPERATIONS.yaml',
  'docs/qst/BETA_ISSUE_REGISTER.yaml',
  'docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml',
  'reports/qst/QST-256-REGRESSION.json',
  'reports/qst/QST-400-HUMAN-REVIEW.json',
  'docs/qst/PROVIDER_EVAL_RUN.yaml',
  'docs/qst/INCIDENT_LIVE_DRILL.yaml',
  'tools/qst/quest_planning_eval_results.json',
};

void main(List<String> arguments) {
  final failures = <String>[];
  final phase =
      arguments
          .where((argument) => argument.startsWith('--phase='))
          .map((argument) => argument.substring('--phase='.length))
          .firstOrNull ??
      'implementation';
  if (phase != 'implementation' && phase != 'evidence') {
    _fail('Unsupported phase: $phase');
  }

  final manifest = File(manifestPath);
  if (!manifest.existsSync()) {
    _fail('Missing $manifestPath');
  }
  final manifestText = manifest.readAsStringSync().replaceAll('\r\n', '\n');
  for (final required in [
    'every_changed_path_classified_once: true',
    'clean_worktree: required',
    'evidence_outputs_only: true',
    'unclassified_path_allowed: false',
    'overlapping_scope_allowed: false',
    'dirty_worktree_is_candidate: false',
  ]) {
    if (!manifestText.contains(required)) {
      failures.add('Manifest missing: $required');
    }
  }
  for (final entry in scopeGroups.entries) {
    if (!manifestText.contains('  ${entry.key}:')) {
      failures.add('Manifest missing scope group: ${entry.key}');
    }
    for (final prefix in entry.value) {
      if (!manifestText.contains('    - $prefix')) {
        failures.add('Manifest missing scope prefix: $prefix');
      }
    }
  }
  for (final path in postCandidateEvidenceOutputs) {
    if (!manifestText.contains('  - $path')) {
      failures.add('Manifest missing evidence output: $path');
    }
  }

  final branchResult = Process.runSync('git', ['branch', '--show-current']);
  if (branchResult.exitCode != 0) {
    failures.add('Unable to resolve current branch.');
  } else {
    final branch = resolveCandidateBranch(
      gitBranch: branchResult.stdout.toString(),
    );
    if (branch != expectedBranch) {
      failures.add(
        'Candidate work must stay on $expectedBranch (resolved: ${branch.isEmpty ? 'unknown' : branch}).',
      );
    }
  }

  final changedPaths = candidateChangedPaths();
  final counts = <String, int>{for (final group in scopeGroups.keys) group: 0};

  if (phase == 'implementation') {
    for (final path in changedPaths) {
      final matches = scopeGroups.entries
          .where((entry) => entry.value.any((prefix) => _matches(path, prefix)))
          .map((entry) => entry.key)
          .toList();
      if (matches.isEmpty) {
        failures.add('Unclassified implementation path: $path');
      } else if (matches.length > 1) {
        failures.add('Overlapping implementation path: $path -> $matches');
      } else {
        counts.update(matches.single, (value) => value + 1);
      }
    }
  } else {
    final unexpected = changedPaths.difference(postCandidateEvidenceOutputs);
    for (final path in unexpected) {
      failures.add(
        'Post-candidate product or unapproved evidence change: $path',
      );
    }
  }

  if (arguments.contains('--require-clean') && changedPaths.isNotEmpty) {
    failures.add(
      'Candidate cut requires a clean worktree (${changedPaths.length} paths).',
    );
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Candidate scope partition failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln(
    'Candidate scope partition passed for $phase (${changedPaths.length} paths).',
  );
  if (phase == 'implementation') {
    for (final entry in counts.entries) {
      stdout.writeln('- ${entry.key}: ${entry.value}');
    }
  }
}

bool _matches(String path, String prefix) {
  if (prefix.endsWith('/')) return path.startsWith(prefix);
  return path == prefix;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
