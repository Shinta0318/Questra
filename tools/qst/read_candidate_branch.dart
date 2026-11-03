import 'dart:io';

import 'verify_candidate_scope_partition.dart' show candidateScopeBranch;

String reviewedCandidateBranch(String scopeManifest, String candidateManifest) {
  final scope = candidateScopeBranch(scopeManifest);
  final matches = RegExp(
    r'^branch:\s*"?(codex/[a-z0-9][a-z0-9-]*)"?\s*$',
    multiLine: true,
  ).allMatches(candidateManifest).toList();
  final candidate = matches.length == 1 ? matches.single.group(1) : null;
  if (scope == null || candidate == null || scope != candidate) {
    throw StateError('Candidate branch manifests are missing or disagree.');
  }
  return scope;
}

void main() {
  try {
    stdout.writeln(
      reviewedCandidateBranch(
        File('docs/qst/CANDIDATE_SCOPE_PARTITION.yaml').readAsStringSync(),
        File('docs/qst/BETA_CANDIDATE.yaml').readAsStringSync(),
      ),
    );
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
