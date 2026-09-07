import 'dart:io';

const packagePath = 'docs/qst/CANDIDATE_ASSET_PACKAGE.yaml';

Future<void> main(List<String> arguments) async {
  final requireRelease = arguments.contains('--require-release');
  final file = File(packagePath);
  if (!file.existsSync()) _fail('Candidate asset package manifest is missing.');
  final content = file.readAsStringSync().replaceAll('\r\n', '\n');
  final failures = <String>[];
  final candidateSourceCommit = RegExp(
    r'^candidate_source_commit: "([a-f0-9]{40})"$',
    multiLine: true,
  ).firstMatch(content)?.group(1);
  if (candidateSourceCommit == null) {
    failures.add('Candidate asset package has no valid source commit.');
  }
  final entries = RegExp(
    r'  - path: "([^"]+)"\n'
    r'    bytes: (\d+)\n'
    r'    sha256: "([a-f0-9]{64})"\n'
    r'    provenance: ([a-z_]+)\n'
    r'    release_allowed: (true|false)',
  ).allMatches(content).toList();
  final bundled = _bundledAssets(failures);
  final manifested = entries.map((entry) => entry.group(1)!).toSet();
  if (bundled.length != manifested.length || !bundled.containsAll(manifested)) {
    failures.add('Candidate asset manifest does not exactly match pubspec.');
  }
  for (final entry in entries) {
    final path = entry.group(1)!;
    if (path.contains('/mockups/')) {
      failures.add(
        'Repository reference is included in candidate bundle: $path',
      );
      continue;
    }
    final asset = File(path);
    if (!asset.existsSync()) {
      failures.add('Candidate asset is missing: $path');
      continue;
    }
    if (asset.lengthSync() != int.parse(entry.group(2)!)) {
      failures.add('Candidate asset size is stale: $path');
    }
    if (await _sha256(path) != entry.group(3)) {
      failures.add('Candidate asset hash is stale: $path');
    }
    if (requireRelease && entry.group(5) != 'true') {
      failures.add('Candidate asset is not approved: $path');
    }
  }
  for (final required in const [
    'repository_reference_in_flutter_bundle_allowed: false',
    'untracked_runtime_asset_allowed: false',
    'hash_change_preserves_approval: false',
    'approval_without_source_record_allowed: false',
    'repository_presence_proves_ownership: false',
  ]) {
    if (!content.contains(required))
      failures.add('Missing guardrail: $required');
  }
  if (requireRelease) {
    final head = _command(['git', 'rev-parse', 'HEAD']).trim();
    if (candidateSourceCommit != head) {
      failures.add('Release candidate asset package is not bound to HEAD.');
    }
    for (final required in const [
      'status: approved',
      'release_ready: true',
      'working_tree_clean_at_generation: true',
    ]) {
      if (!content.contains(required))
        failures.add('Release gate missing: $required');
    }
  }
  if (failures.isNotEmpty) {
    stderr.writeln('Candidate asset package verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    requireRelease
        ? 'Candidate asset release package passed.'
        : 'Candidate asset package hygiene passed; ownership review may remain pending.',
  );
}

Set<String> _bundledAssets(List<String> failures) {
  final pubspec = File('apps/mobile/pubspec.yaml').readAsStringSync();
  final result = <String>{};
  for (final match in RegExp(
    r'^    - (assets/[^#\r\n]+?)\s*$',
    multiLine: true,
  ).allMatches(pubspec)) {
    final path = 'apps/mobile/${match.group(1)!.trim()}';
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      result.addAll(
        Directory(path)
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => file.path.replaceAll('\\', '/')),
      );
    } else if (type == FileSystemEntityType.file) {
      result.add(path.replaceAll('\\', '/'));
    } else {
      failures.add('Registered asset is missing: $path');
    }
  }
  return result;
}

Future<String?> _sha256(String path) async {
  final command = Platform.isWindows ? 'certutil' : 'sha256sum';
  final args = Platform.isWindows ? ['-hashfile', path, 'SHA256'] : [path];
  final result = await Process.run(command, args);
  if (result.exitCode != 0) return null;
  return RegExp(
    r'\b[a-fA-F0-9]{64}\b',
  ).firstMatch(result.stdout as String)?.group(0)?.toLowerCase();
}

String _command(List<String> command) {
  final result = Process.runSync(command.first, command.skip(1).toList());
  if (result.exitCode != 0) _fail(result.stderr as String);
  return result.stdout as String;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
