import 'dart:convert';
import 'dart:io';

const manifestPath = 'docs/qst/CANDIDATE_PREFLIGHT.yaml';
const maxTextBytes = 2 * 1024 * 1024;

final secretPatterns = <RegExp>[
  RegExp(r'AIza[0-9A-Za-z_-]{30,}'),
  RegExp(r'sb_secret_[0-9A-Za-z_-]{20,}'),
  RegExp(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
  RegExp(r'Bearer\s+[A-Za-z0-9._~+/-]{24,}', caseSensitive: false),
];

void main(List<String> args) {
  final failures = <String>[];
  final manifest = File(manifestPath);
  if (!manifest.existsSync()) {
    failures.add('Missing $manifestPath');
  } else {
    final text = manifest.readAsStringSync();
    for (final required in [
      'clean_worktree: required',
      'secret_scan: required',
      'dirty_worktree_is_candidate: false',
    ]) {
      if (!text.contains(required)) failures.add('Manifest missing: $required');
    }
  }

  final scannedFiles = scanCandidateTextFiles(failures: failures);

  final status = Process.runSync('git', ['status', '--porcelain=v1', '-uall']);
  if (status.exitCode != 0) {
    failures.add('Unable to inspect git worktree.');
  }
  final changedEntries = status.stdout
      .toString()
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);
  final changes = changedEntries.length;
  final requireClean = args.contains('--require-clean');
  if (requireClean && changes > 0) {
    failures.add('Candidate worktree is dirty ($changes entries).');
    for (final entry in changedEntries) {
      failures.add(
        'Dirty path: ${entry.length > 3 ? entry.substring(3) : entry}',
      );
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Candidate preflight failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Candidate preflight passed.');
  stdout.writeln(
    'Scanned $scannedFiles text source files; worktree changes: $changes.',
  );
  if (!requireClean && changes > 0) {
    stdout.writeln(
      'Development mode only: rerun with --require-clean for a candidate.',
    );
  }
}

int scanCandidateTextFiles({
  required List<String> failures,
  String? workingDirectory,
}) {
  final root = workingDirectory ?? Directory.current.path;
  final inventory = Process.runSync(
    'git',
    ['ls-files', '-z', '--cached', '--others', '--exclude-standard'],
    workingDirectory: root,
    stdoutEncoding: utf8,
  );
  if (inventory.exitCode != 0) {
    failures.add('Unable to list candidate files for secret scan.');
    return 0;
  }
  var scanned = 0;
  final paths = inventory.stdout
      .toString()
      .split('\u0000')
      .where((path) => path.isNotEmpty)
      .toSet();
  for (final path in paths) {
    final file = File('$root/$path');
    final type = FileSystemEntity.typeSync(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) continue;
    if (type == FileSystemEntityType.link) {
      failures.add('Candidate file is a symlink and was not scanned: $path');
      continue;
    }
    if (type != FileSystemEntityType.file) continue;
    if (file.lengthSync() > maxTextBytes) {
      if (_isTextSource(path))
        failures.add('Candidate text file exceeds the scan limit: $path');
      continue;
    }
    String content;
    try {
      content = utf8.decode(file.readAsBytesSync());
    } on FormatException {
      if (_isTextSource(path))
        failures.add('Candidate text file is not UTF-8: $path');
      continue;
    }
    if (content.contains('\u0000')) {
      if (_isTextSource(path))
        failures.add('Candidate text file contains binary data: $path');
      continue;
    }
    scanned++;
    for (final pattern in secretPatterns) {
      if (pattern.hasMatch(content)) {
        failures.add('Potential secret value in $path');
        break;
      }
    }
  }
  return scanned;
}

bool _isTextSource(String path) {
  final normalized = path.replaceAll('\\', '/').toLowerCase();
  return const [
    '.dart',
    '.ts',
    '.js',
    '.html',
    '.yaml',
    '.yml',
    '.json',
    '.md',
    '.sql',
    '.ps1',
    '.sh',
    '.toml',
    '.txt',
    '.env',
    '.svg',
    '.xml',
    '.gradle',
    '.kt',
    '.java',
    '.py',
  ].any(normalized.endsWith);
}
