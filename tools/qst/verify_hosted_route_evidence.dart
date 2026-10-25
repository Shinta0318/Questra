import 'dart:convert';
import 'dart:io';

const hostedRouteEvidencePath = 'docs/qst/HOSTED_ROUTE_EVIDENCE.json';

List<String> validateHostedRouteEvidence(
  Map<String, dynamic> manifest, {
  required String candidateSha,
  required String migrationHead,
  required String projectRef,
  required bool worktreeClean,
  required bool Function(String path) fileExists,
}) {
  final errors = <String>[];
  if (manifest['version'] != 1 ||
      manifest['status'] != 'verified' ||
      manifest['candidateSha'] != candidateSha ||
      manifest['migrationHead'] != migrationHead ||
      manifest['projectRef'] != projectRef ||
      manifest['workingTreeCleanAtExecution'] != true ||
      !worktreeClean) {
    errors.add(
      'Hosted route evidence is not bound to the clean current candidate.',
    );
  }
  final checks = manifest['checks'];
  for (final key in const [
    'snapshotV2Reload',
    'applyAndUndo',
    'taskVersionConflict',
    'lostResponseRetry',
    'crossAccountDenied',
    'ephemeralDataRemoved',
  ]) {
    if (checks is! Map || checks[key] != 'passed') {
      errors.add('Missing Hosted route check: $key.');
    }
  }
  final paths = manifest['sanitizedEvidencePaths'];
  if (paths is! List || paths.isEmpty) {
    errors.add('Sanitized Hosted evidence files are missing.');
  } else {
    for (final value in paths) {
      if (value is! String ||
          !value.startsWith('reports/qst/evidence/') ||
          value.contains('..') ||
          !fileExists(value)) {
        errors.add('Invalid Hosted evidence path: $value.');
      }
    }
  }
  return errors;
}

void main() {
  final file = File(hostedRouteEvidencePath);
  if (!file.existsSync()) {
    stderr.writeln('Hosted route evidence manifest is missing.');
    exitCode = 1;
    return;
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) {
    stderr.writeln('Hosted route evidence manifest is invalid.');
    exitCode = 1;
    return;
  }
  final sha = Process.runSync('git', ['rev-parse', 'HEAD']);
  final status = Process.runSync('git', ['status', '--porcelain']);
  if (sha.exitCode != 0 || status.exitCode != 0) {
    stderr.writeln('Unable to verify candidate Git state.');
    exitCode = 1;
    return;
  }
  final migrationNames =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.endsWith('.sql'))
          .toList()
        ..sort();
  final betaProject = File(
    'docs/qst/BETA_SUPABASE_PROJECT.yaml',
  ).readAsStringSync();
  final projectRef =
      RegExp(
        r'^  ref: "([a-z0-9]+)"$',
        multiLine: true,
      ).firstMatch(betaProject)?.group(1) ??
      '';
  final errors = validateHostedRouteEvidence(
    Map<String, dynamic>.from(decoded),
    candidateSha: (sha.stdout as String).trim(),
    migrationHead: migrationNames.last,
    projectRef: projectRef,
    worktreeClean: (status.stdout as String).trim().isEmpty,
    fileExists: (path) =>
        File(path).existsSync() && File(path).lengthSync() > 0,
  );
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln('Hosted route evidence passed for current SHA.');
}
