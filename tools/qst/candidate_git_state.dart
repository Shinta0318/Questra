import 'dart:convert';
import 'dart:io';

const candidateEvidenceOutputs = <String>{
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

String candidateSourceCommit({
  String manifestPath = 'docs/qst/BETA_CANDIDATE.yaml',
}) {
  final manifest = File(manifestPath).readAsStringSync();
  final matches = RegExp(
    r'^source_commit:\s*"?([a-f0-9]{40})"?\s*$',
    multiLine: true,
  ).allMatches(manifest).toList();
  if (matches.length != 1) {
    throw StateError('Candidate manifest must contain one source commit.');
  }
  return matches.single.group(1)!;
}

bool candidateSourceHasOnlyEvidenceCommits(
  String sourceCommit, {
  String? workingDirectory,
}) {
  if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(sourceCommit)) return false;
  final ancestor = Process.runSync('git', [
    'merge-base',
    '--is-ancestor',
    sourceCommit,
    'HEAD',
  ], workingDirectory: workingDirectory);
  if (ancestor.exitCode != 0) return false;
  final changed = Process.runSync(
    'git',
    ['diff', '--name-only', '--no-renames', '-z', sourceCommit, 'HEAD'],
    workingDirectory: workingDirectory,
    stdoutEncoding: utf8,
  );
  if (changed.exitCode != 0) return false;
  final paths = changed.stdout
      .toString()
      .split('\x00')
      .where((path) => path.isNotEmpty)
      .toSet();
  return paths.every(candidateEvidenceOutputs.contains);
}

String resolveCandidateBranch({
  required String gitBranch,
  Map<String, String>? environment,
}) {
  final resolvedEnvironment = environment ?? Platform.environment;
  final values = [
    gitBranch,
    resolvedEnvironment['GITHUB_HEAD_REF'] ?? '',
    resolvedEnvironment['GITHUB_REF_NAME'] ?? '',
  ];
  return values
      .map((value) => value.trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
}

// Inspect the index and working tree separately: opposite edits can cancel in
// `git diff HEAD` while the staged candidate still contains different code.
Set<String> candidateChangedPaths({String? workingDirectory}) {
  Set<String> paths(List<String> arguments) {
    final result = Process.runSync(
      'git',
      arguments,
      workingDirectory: workingDirectory,
      stdoutEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw StateError('Unable to inspect candidate git changes.');
    }
    return result.stdout
        .toString()
        .split('\x00')
        .where((path) => path.isNotEmpty)
        .toSet();
  }

  return {
    ...paths([
      'diff',
      '--cached',
      '--name-only',
      '--no-renames',
      '--ignore-submodules=none',
      '-z',
    ]),
    ...paths([
      'diff',
      '--name-only',
      '--no-renames',
      '--ignore-submodules=none',
      '-z',
    ]),
    ...paths(['ls-files', '--others', '--exclude-standard', '-z']),
  };
}
