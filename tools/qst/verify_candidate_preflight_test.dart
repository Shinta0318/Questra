import 'dart:io';

import 'verify_candidate_preflight.dart' as preflight;

void main() {
  final temp = Directory.systemTemp.createTempSync('questra-preflight-');
  try {
    final root = Directory('${temp.path}/fixture')..createSync();
    final docs = Directory('${root.path}/docs')..createSync();
    final reports = Directory('${root.path}/reports')..createSync();
    final init = Process.runSync('git', [
      'init',
      '-q',
    ], workingDirectory: root.path);
    if (init.exitCode != 0) throw StateError('Unable to create Git fixture.');

    final dummySecret = 'sb_' + 'secret_' + ('a' * 20);
    File('${root.path}/.gitignore').writeAsStringSync('local.env\n');
    File(
      '${docs.path}/contract.md',
    ).writeAsStringSync('fixture=$dummySecret\n');
    File(
      '${reports.path}/findings.md',
    ).writeAsStringSync('fixture=$dummySecret\n');
    File('${root.path}/local.env').writeAsStringSync('fixture=$dummySecret\n');
    final add = Process.runSync('git', [
      'add',
      '.gitignore',
      'docs/contract.md',
    ], workingDirectory: root.path);
    if (add.exitCode != 0) throw StateError('Unable to stage Git fixture.');

    final failures = <String>[];
    final scanned = preflight.scanCandidateTextFiles(
      failures: failures,
      workingDirectory: root.path,
    );
    if (scanned < 3 ||
        !failures.any((item) => item.contains('docs/contract.md')) ||
        !failures.any((item) => item.contains('reports/findings.md')) ||
        failures.any((item) => item.contains('local.env')) ||
        failures.any((item) => item.contains(dummySecret))) {
      throw StateError(
        'Candidate inventory did not safely scan tracked and untracked text files: $failures',
      );
    }

    File('${docs.path}/contract.md').writeAsStringSync('safe fixture\n');
    File('${reports.path}/findings.md').writeAsStringSync('safe fixture\n');
    final cleanFailures = <String>[];
    preflight.scanCandidateTextFiles(
      failures: cleanFailures,
      workingDirectory: root.path,
    );
    if (cleanFailures.isNotEmpty)
      throw StateError('Clean fixture was rejected: $cleanFailures');
  } finally {
    if (temp.parent.absolute.path != Directory.systemTemp.absolute.path) {
      throw StateError('Temporary fixture escaped the system temp directory.');
    }
    temp.deleteSync(recursive: true);
  }
  stdout.writeln('Candidate secret scan inventory test passed.');
}
