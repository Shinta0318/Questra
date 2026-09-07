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
          !result.stderr.toString().contains('does not match current HEAD')) {
        throw StateError('Gate accepted a stale SHA: ${result.stderr}');
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
