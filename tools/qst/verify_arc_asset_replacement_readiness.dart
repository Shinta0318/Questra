import 'dart:io';

const readinessPath = 'docs/qst/ARC_ASSET_REPLACEMENT_READINESS.yaml';

void main(List<String> args) {
  final failures = <String>[];
  final readiness = _read(readinessPath, failures);
  for (final snippet in const [
    'runtime_asset_count: 7',
    'current_release_allowed_count: 0',
    'replacement_requires_new_hash: true',
    'provenance_record_requires_exact_hash: true',
    'visual_approval_proves_distribution_rights: false',
    'reference_mockup_bundled: false',
  ]) {
    if (!readiness.contains(snippet))
      failures.add('$readinessPath missing "$snippet"');
  }

  final inventory = Process.runSync('dart', [
    'run',
    'tools/qst/verify_arc_asset_provenance.dart',
    if (args.contains('--require-release')) '--require-release',
  ]);
  if (inventory.exitCode != 0) {
    failures.add(inventory.stderr.toString().trim());
  }
  final package = Process.runSync('dart', [
    'run',
    'tools/qst/verify_candidate_asset_package.dart',
    if (args.contains('--require-release')) '--require-release',
  ]);
  if (package.exitCode != 0) failures.add(package.stderr.toString().trim());

  if (failures.isNotEmpty) {
    stderr.writeln('Arc asset replacement readiness failed:');
    for (final failure in failures.where((value) => value.isNotEmpty)) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }
  stdout.writeln(
    args.contains('--require-release')
        ? 'Arc asset replacement release gate passed.'
        : 'Arc asset inventory is consistent; release rights remain blocked.',
  );
}

String _read(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing $path');
    return '';
  }
  return file.readAsStringSync();
}
