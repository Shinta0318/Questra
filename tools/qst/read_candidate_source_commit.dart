import 'dart:io';

import 'candidate_git_state.dart';

void main() {
  try {
    final source = candidateSourceCommit();
    if (!candidateSourceHasOnlyEvidenceCommits(source)) {
      throw StateError(
        'Candidate source has runtime changes in later commits.',
      );
    }
    stdout.writeln(source);
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
