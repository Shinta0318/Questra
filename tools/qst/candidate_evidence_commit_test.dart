import 'dart:io';

import 'candidate_git_state.dart';

void main() {
  final directory = Directory.systemTemp.createTempSync('questra-candidate-');
  try {
    final root = directory.path;
    void git(List<String> args) {
      final result = Process.runSync('git', args, workingDirectory: root);
      if (result.exitCode != 0) {
        throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
      }
    }

    git(['init', '-q']);
    git(['config', 'user.name', 'Questra Test']);
    git(['config', 'user.email', 'test@example.invalid']);
    File(
      '${root}${Platform.pathSeparator}app.txt',
    ).writeAsStringSync('code v1');
    git(['add', 'app.txt']);
    git(['commit', '-qm', 'candidate source']);
    final source = Process.runSync('git', [
      'rev-parse',
      'HEAD',
    ], workingDirectory: root).stdout.toString().trim();
    if (!candidateSourceHasOnlyEvidenceCommits(
      source,
      workingDirectory: root,
    )) {
      throw StateError('The candidate source must be valid at HEAD.');
    }

    final evidence = File(
      '${root}${Platform.pathSeparator}docs${Platform.pathSeparator}qst'
      '${Platform.pathSeparator}EXTERNAL_BETA_GO_NO_GO.yaml',
    );
    evidence.parent.createSync(recursive: true);
    evidence.writeAsStringSync('candidate_source_commit: $source\n');
    git(['add', 'docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml']);
    git(['commit', '-qm', 'candidate evidence']);
    if (!candidateSourceHasOnlyEvidenceCommits(
      source,
      workingDirectory: root,
    )) {
      throw StateError('An evidence-only descendant must remain valid.');
    }

    File(
      '${root}${Platform.pathSeparator}app.txt',
    ).writeAsStringSync('code v2');
    git(['add', 'app.txt']);
    git(['commit', '-qm', 'runtime change']);
    if (candidateSourceHasOnlyEvidenceCommits(source, workingDirectory: root)) {
      throw StateError('A later runtime change must invalidate the candidate.');
    }
    if (candidateSourceHasOnlyEvidenceCommits(
      'not-a-sha',
      workingDirectory: root,
    )) {
      throw StateError('A malformed source SHA must be rejected.');
    }
    print('Candidate evidence commit fixtures: PASS.');
  } finally {
    directory.deleteSync(recursive: true);
  }
}
