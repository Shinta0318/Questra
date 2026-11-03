import 'read_candidate_branch.dart';

void main() {
  const scope = 'branch: codex/reviewed-candidate\n';
  const candidate = 'branch: "codex/reviewed-candidate"\n';
  if (reviewedCandidateBranch(scope, candidate) != 'codex/reviewed-candidate') {
    throw StateError('Matching reviewed candidate branch was rejected.');
  }

  for (final invalid in [
    'branch: "codex/other-candidate"\n',
    'branch: "main"\n',
    '$candidate$candidate',
  ]) {
    try {
      reviewedCandidateBranch(scope, invalid);
      throw StateError(
        'Unreviewed or ambiguous candidate branch was accepted.',
      );
    } on StateError catch (error) {
      if (error.message ==
          'Unreviewed or ambiguous candidate branch was accepted.') {
        rethrow;
      }
    }
  }
  print('Candidate branch manifest agreement: PASS');
}
