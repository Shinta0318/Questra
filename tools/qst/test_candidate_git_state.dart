import 'dart:io';

import 'candidate_git_state.dart';

void main() {
  if (resolveCandidateBranch(
        gitBranch: '',
        environment: const {
          'GITHUB_HEAD_REF': 'codex/initial-questra-structure-pr',
          'GITHUB_REF_NAME': '19/merge',
        },
      ) !=
      'codex/initial-questra-structure-pr') {
    throw StateError('Pull request head branch was not resolved.');
  }
  if (resolveCandidateBranch(
        gitBranch: 'codex/initial-questra-structure-pr',
        environment: const {'GITHUB_HEAD_REF': 'unexpected'},
      ) !=
      'codex/initial-questra-structure-pr') {
    throw StateError('Local branch must take precedence over CI metadata.');
  }

  final verifier = File(
    'tools/qst/verify_clean_candidate_evidence.dart',
  ).absolute.path;
  final sourceReader = File(
    'tools/qst/read_candidate_source_commit.dart',
  ).absolute.path;
  final temp = Directory.systemTemp.createTempSync('questra-git-gate-');
  var count = 0;
  try {
    void scenario(
      String name,
      void Function(Directory, void Function(List<String>)) run,
    ) {
      final root = Directory('${temp.path}/$name')..createSync();
      void git(List<String> args) {
        final result = Process.runSync(
          'git',
          args,
          workingDirectory: root.path,
        );
        if (result.exitCode != 0)
          throw StateError('git failed: ${result.stderr}');
      }

      git(['init', '-q']);
      git(['config', 'user.name', 'Questra test fixture']);
      git(['config', 'user.email', 'fixture@example.invalid']);
      git(['config', 'commit.gpgsign', 'false']);
      File('${root.path}/runtime.dart').writeAsStringSync('original\n');
      git(['add', '.']);
      git(['commit', '-qm', 'fixture']);
      run(root, git);
      count++;
      stdout.writeln('PASS $name');
    }

    void expectPaths(Directory root, Set<String> expected) {
      final actual = candidateChangedPaths(workingDirectory: root.path);
      if (actual.difference(expected).isNotEmpty ||
          expected.difference(actual).isNotEmpty) {
        throw StateError('Expected $expected; got $actual');
      }
    }

    scenario('clean', (root, git) => expectPaths(root, {}));
    scenario('unstaged', (root, git) {
      File('${root.path}/runtime.dart').writeAsStringSync('modified\n');
      expectPaths(root, {'runtime.dart'});
    });
    scenario('staged-runtime-rejected', (root, git) {
      File('${root.path}/runtime.dart').writeAsStringSync('modified\n');
      git(['add', '.']);
      expectPaths(root, {'runtime.dart'});
      final head = Process.runSync('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: root.path).stdout.toString().trim();
      final result = Process.runSync(Platform.resolvedExecutable, [
        verifier,
        '--expected-sha=$head',
      ], workingDirectory: root.path);
      if (result.exitCode == 0 ||
          !result.stderr.toString().contains(
            'non-evidence changes: runtime.dart',
          )) {
        throw StateError(
          'Gate did not reject staged runtime: ${result.stderr}',
        );
      }
    });
    scenario('opposite-index-and-worktree-edits', (root, git) {
      File('${root.path}/runtime.dart').writeAsStringSync('staged\n');
      git(['add', '.']);
      File('${root.path}/runtime.dart').writeAsStringSync('original\n');
      expectPaths(root, {'runtime.dart'});
    });
    scenario('rename-detects-both-paths', (root, git) {
      git(['mv', 'runtime.dart', 'renamed.dart']);
      expectPaths(root, {'runtime.dart', 'renamed.dart'});
    });
    scenario('staged-delete', (root, git) {
      git(['rm', 'runtime.dart']);
      expectPaths(root, {'runtime.dart'});
    });
    scenario('unicode-and-spaces', (root, git) {
      File('${root.path}/日本語 の変更.dart').writeAsStringSync('test');
      git(['add', '.']);
      expectPaths(root, {'日本語 の変更.dart'});
    });
    scenario('untracked', (root, git) {
      File('${root.path}/new.dart').writeAsStringSync('new');
      expectPaths(root, {'new.dart'});
    });
    scenario('ignored', (root, git) {
      File(
        '${root.path}/.git/info/exclude',
      ).writeAsStringSync('\nlocal.log\n', mode: FileMode.append);
      File('${root.path}/local.log').writeAsStringSync('ignored');
      expectPaths(root, {});
    });
    scenario('wrong-sha-rejected', (root, git) {
      final result = Process.runSync(Platform.resolvedExecutable, [
        verifier,
        '--expected-sha=${'0' * 40}',
      ], workingDirectory: root.path);
      if (result.exitCode == 0 ||
          !result.stderr.toString().contains(
            'not an ancestor with evidence-only commits',
          )) {
        throw StateError('Gate accepted a stale SHA: ${result.stderr}');
      }
    });
    scenario('source-manifest-and-evidence-descendant', (root, git) {
      final head = Process.runSync('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: root.path).stdout.toString().trim();
      Directory('${root.path}/docs/qst').createSync(recursive: true);
      final manifest = File('${root.path}/docs/qst/BETA_CANDIDATE.yaml')
        ..writeAsStringSync('version: 1\nsource_commit: "$head"\n');
      if (candidateSourceCommit(manifestPath: manifest.path) != head) {
        throw StateError('Candidate manifest source was not read.');
      }
      manifest.writeAsStringSync(
        'version: 1\nsource_commit: "$head"\nsource_commit: "$head"\n',
      );
      try {
        candidateSourceCommit(manifestPath: manifest.path);
        throw StateError('Duplicate source commit was accepted.');
      } on StateError catch (error) {
        if (error.message == 'Duplicate source commit was accepted.') rethrow;
      }
      manifest.writeAsStringSync('version: 1\nsource_commit: "$head"\n');
      git(['add', 'docs/qst/BETA_CANDIDATE.yaml']);
      git(['commit', '-qm', 'evidence only']);
      if (!candidateSourceHasOnlyEvidenceCommits(
        head,
        workingDirectory: root.path,
      )) {
        throw StateError('Evidence-only descendant must pass.');
      }
      final accepted = Process.runSync(Platform.resolvedExecutable, [
        sourceReader,
      ], workingDirectory: root.path);
      if (accepted.exitCode != 0 || accepted.stdout.toString().trim() != head) {
        throw StateError('Candidate reader rejected evidence-only commit.');
      }
      File('${root.path}/runtime.dart').writeAsStringSync('changed\n');
      git(['add', 'runtime.dart']);
      git(['commit', '-qm', 'runtime change']);
      if (candidateSourceHasOnlyEvidenceCommits(
        head,
        workingDirectory: root.path,
      )) {
        throw StateError('Runtime descendant was accepted.');
      }
      final rejected = Process.runSync(Platform.resolvedExecutable, [
        sourceReader,
      ], workingDirectory: root.path);
      if (rejected.exitCode == 0) {
        throw StateError('Candidate reader accepted runtime descendant.');
      }
    });
  } finally {
    // Only remove the test-owned directory returned by createTempSync.
    if (temp.parent.absolute.path != Directory.systemTemp.absolute.path) {
      throw StateError('Temporary fixture escaped the system temp directory.');
    }
    temp.deleteSync(recursive: true);
  }
  stdout.writeln('$count candidate git-state scenarios passed.');
}
