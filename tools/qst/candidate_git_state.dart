import 'dart:convert';
import 'dart:io';

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
