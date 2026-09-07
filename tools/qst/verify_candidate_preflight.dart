import 'dart:io';

const manifestPath = 'docs/qst/CANDIDATE_PREFLIGHT.yaml';
const scanRoots = <String>[
  'apps/mobile/lib',
  'apps/mobile/web',
  'supabase/functions',
  '.github/workflows',
];

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

  var scannedFiles = 0;
  for (final rootPath in scanRoots) {
    final root = Directory(rootPath);
    if (!root.existsSync()) {
      failures.add('Missing scan root: $rootPath');
      continue;
    }
    for (final entity in root.listSync(recursive: true).whereType<File>()) {
      if (!_isTextSource(entity.path) ||
          entity.lengthSync() > 2 * 1024 * 1024) {
        continue;
      }
      scannedFiles++;
      final content = entity.readAsStringSync();
      for (final pattern in secretPatterns) {
        if (pattern.hasMatch(content)) {
          failures.add('Potential secret value in ${entity.path}');
          break;
        }
      }
    }
  }

  final status = Process.runSync('git', ['status', '--porcelain=v1']);
  if (status.exitCode != 0) {
    failures.add('Unable to inspect git worktree.');
  }
  final changes = status.stdout
      .toString()
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().isNotEmpty)
      .length;
  final requireClean = args.contains('--require-clean');
  if (requireClean && changes > 0) {
    failures.add('Candidate worktree is dirty ($changes entries).');
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
  ].any(normalized.endsWith);
}
