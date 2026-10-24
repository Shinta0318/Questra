import 'dart:convert';
import 'dart:io';

const evidencePath = 'docs/qst/PRIMARY_SCREEN_STATE_EVIDENCE.json';

List<String> validatePrimaryScreenEvidence(
  Map<String, dynamic> manifest, {
  required String candidateSha,
  required bool worktreeClean,
  required bool Function(String path) fileExists,
}) {
  final errors = <String>[];
  if (manifest['version'] != 1 ||
      manifest['status'] != 'verified' ||
      manifest['candidateSha'] != candidateSha ||
      manifest['workingTreeCleanAtCapture'] != true ||
      !worktreeClean) {
    errors.add('Evidence is not verified for the clean current SHA.');
  }
  const screens = [
    'home',
    'arc',
    'quest',
    'mission',
    'task',
    'trail',
    'route_review',
  ];
  const widths = [360, 390, 430];
  const states = ['empty', 'loading', 'error', 'offline'];
  final entries = manifest['screenshots'];
  if (entries is! List) {
    errors.add('Screenshots must be a list.');
    return errors;
  }
  final evidence = entries
      .whereType<Map>()
      .map(Map<String, dynamic>.from)
      .toList();
  for (final screen in screens) {
    for (final width in widths) {
      if (!evidence.any(
        (entry) =>
            entry['screen'] == screen &&
            entry['width'] == width &&
            entry['textScale'] == 1.0,
      )) {
        errors.add('Missing screenshot: $screen at ${width}px.');
      }
    }
    if (!evidence.any(
      (entry) =>
          entry['screen'] == screen &&
          entry['width'] == 390 &&
          entry['textScale'] == 2.0,
    )) {
      errors.add('Missing large-text screenshot: $screen.');
    }
    for (final state in states) {
      if (!evidence.any(
        (entry) =>
            entry['screen'] == screen &&
            entry['state'] == state &&
            entry['width'] == 390,
      )) {
        errors.add('Missing state evidence: $screen/$state.');
      }
    }
  }
  for (final state in const ['permission_denied', 'recovery_incomplete']) {
    if (!evidence.any(
      (entry) => entry['screen'] == 'route_review' && entry['state'] == state,
    )) {
      errors.add('Missing route recovery state: $state.');
    }
  }
  if (!evidence.any(
    (entry) => entry['screen'] == 'arc' && entry['state'] == 'ai_fallback',
  )) {
    errors.add('Missing Arc AI fallback fixture.');
  }
  for (final entry in evidence) {
    final path = entry['path'];
    if (path is! String ||
        !path.startsWith('reports/qst/evidence/') ||
        path.contains('..') ||
        !fileExists(path)) {
      errors.add('Invalid or missing screenshot path: $path.');
    }
  }
  final physical = manifest['physical'];
  if (physical is! Map ||
      const [
        'talkback',
        'keyboard',
        'reduceMotion',
        'haptics',
      ].any((key) => physical[key] != 'passed')) {
    errors.add('Physical accessibility evidence is incomplete.');
  }
  return errors;
}

void main() {
  final file = File(evidencePath);
  if (!file.existsSync()) {
    stderr.writeln('Primary state evidence manifest is missing.');
    exitCode = 1;
    return;
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) {
    stderr.writeln('Primary state evidence manifest is invalid.');
    exitCode = 1;
    return;
  }
  final head = Process.runSync('git', ['rev-parse', 'HEAD']);
  final status = Process.runSync('git', ['status', '--porcelain']);
  if (head.exitCode != 0 || status.exitCode != 0) {
    stderr.writeln('Unable to verify candidate Git state.');
    exitCode = 1;
    return;
  }
  final errors = validatePrimaryScreenEvidence(
    Map<String, dynamic>.from(decoded),
    candidateSha: (head.stdout as String).trim(),
    worktreeClean: (status.stdout as String).trim().isEmpty,
    fileExists: (path) =>
        File(path).existsSync() && File(path).lengthSync() > 0,
  );
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln('Primary state evidence passed for current SHA.');
}
