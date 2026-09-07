import 'dart:convert';
import 'dart:io';

const manifestPath = 'docs/qst/ARC_ASSET_PROVENANCE.yaml';
const recordDirectory = 'docs/qst/arc_asset_chain_of_title';

Future<void> main(List<String> arguments) async {
  final requireRelease = arguments.contains('--require-release');
  final failures = <String>[];
  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('Arc asset provenance manifest is missing.');
    exit(1);
  }
  final manifest = manifestFile.readAsStringSync().replaceAll('\r\n', '\n');
  final entries = RegExp(
    r'  - path: "([^"]+)"\n'
    r'    bytes: (\d+)\n'
    r'    sha256: "([a-f0-9]{64})"\n'
    r'    usage: ([a-z_]+)\n'
    r'    provenance: ([a-z_]+)\n'
    r'    release_allowed: (true|false)',
  ).allMatches(manifest).toList();
  if (entries.isEmpty) failures.add('Asset manifest has no parseable entries.');

  final tracked = <String>{};
  for (final entry in entries) {
    final path = entry.group(1)!;
    tracked.add(path);
    final file = File(path);
    if (!file.existsSync()) {
      failures.add('Tracked asset is missing: $path');
      continue;
    }
    if (file.lengthSync() != int.parse(entry.group(2)!)) {
      failures.add('Asset size changed without provenance review: $path');
    }
    final hash = await _sha256(path);
    if (hash != entry.group(3)) {
      failures.add('Asset hash changed without provenance review: $path');
    }
    final usage = entry.group(4)!;
    final releaseAllowed = entry.group(6) == 'true';
    final record = File('$recordDirectory/${entry.group(3)}.json');
    if (record.existsSync()) {
      _validateChainRecord(
        record: record,
        assetPath: path,
        assetHash: entry.group(3)!,
        failures: failures,
      );
    }
    if (releaseAllowed && !record.existsSync()) {
      failures.add(
        'Release-approved asset lacks a chain-of-title record: $path',
      );
    }
    if (requireRelease && usage == 'runtime' && !releaseAllowed) {
      failures.add('Asset is not approved for release: $path');
    }
    if (requireRelease && usage == 'runtime' && !record.existsSync()) {
      failures.add(
        'Runtime asset lacks a reviewed chain-of-title record: $path',
      );
    }
  }

  final bundled = _bundledAssetsFromPubspec(failures);
  for (final path in bundled.difference(tracked)) {
    failures.add(
      'Bundled asset is missing from the provenance manifest: $path',
    );
  }
  for (final rule in [
    'missing_asset_allowed: false',
    'hash_mismatch_allowed: false',
    'untracked_bundled_asset_allowed: false',
    'unverified_asset_public_release_allowed: false',
    'repository_presence_proves_ownership: false',
    'reference_asset_in_candidate_allowed: false',
    'hash_change_preserves_approval: false',
    'approval_without_source_record_allowed: false',
    'unreviewed_chain_record_release_allowed: false',
    'record_asset_hash_mismatch_allowed: false',
    'secret_or_raw_signature_in_record_allowed: false',
  ]) {
    if (!manifest.contains(rule)) failures.add('Missing guardrail: $rule');
  }
  if (requireRelease) {
    if (!manifest.contains('status: approved') ||
        !manifest.contains('chain_of_title_complete: true') ||
        manifest.contains('product_owner_approval: pending') ||
        manifest.contains('legal_reviewer_approval: pending')) {
      failures.add('Human ownership and legal approvals are incomplete.');
    }
    final package = File('docs/qst/CANDIDATE_ASSET_PACKAGE.yaml');
    if (!package.existsSync() ||
        !package.readAsStringSync().contains('status: approved')) {
      failures.add('Candidate asset package is not approved.');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Arc asset provenance verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    requireRelease
        ? 'Arc asset release provenance verification passed.'
        : 'Arc asset inventory and hashes passed; public release remains blocked.',
  );
}

void _validateChainRecord({
  required File record,
  required String assetPath,
  required String assetHash,
  required List<String> failures,
}) {
  Object? decoded;
  try {
    decoded = jsonDecode(record.readAsStringSync());
  } on FormatException {
    failures.add('Chain-of-title record is not valid JSON: ${record.path}');
    return;
  }
  if (decoded is! Map) {
    failures.add('Chain-of-title record must be an object: ${record.path}');
    return;
  }
  final data = Map<String, dynamic>.from(decoded);
  if (data['schemaVersion'] != 1 ||
      data['assetPath'] != assetPath ||
      data['assetSha256'] != assetHash ||
      data['commercialDistributionAllowed'] != true ||
      data['productDecision'] != 'approved' ||
      data['legalDecision'] != 'approved') {
    failures.add('Chain-of-title record is not release-complete: $assetPath');
  }
  for (final key in [
    'sourceKind',
    'sourceEvidenceRef',
    'creatorController',
    'creationContext',
    'termsName',
    'termsVersion',
    'termsReference',
    'productReviewRef',
    'legalReviewRef',
    'reviewedAtUtc',
  ]) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isEmpty || value == 'pending') {
      failures.add('Chain-of-title record lacks $key: $assetPath');
    }
  }
  final usage = data['reviewedUsage'];
  if (usage is! List || usage.isEmpty) {
    failures.add('Chain-of-title record lacks reviewed usage: $assetPath');
  }
  _findSensitiveKeys(data, assetPath, failures);
}

void _findSensitiveKeys(
  Object? value,
  String assetPath,
  List<String> failures,
) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key.contains('secret') ||
          key.contains('password') ||
          key.contains('token') ||
          key.contains('signature') ||
          key.contains('privateprompt')) {
        failures.add(
          'Chain-of-title record contains a sensitive field: $assetPath',
        );
      }
      _findSensitiveKeys(entry.value, assetPath, failures);
    }
  } else if (value is List) {
    for (final item in value) {
      _findSensitiveKeys(item, assetPath, failures);
    }
  }
}

Set<String> _bundledAssetsFromPubspec(List<String> failures) {
  const pubspecPath = 'apps/mobile/pubspec.yaml';
  final pubspec = File(pubspecPath);
  if (!pubspec.existsSync()) {
    failures.add('Flutter pubspec is missing: $pubspecPath');
    return {};
  }
  final bundled = <String>{};
  final entries = RegExp(
    r'^    - (assets/[^#\r\n]+?)\s*$',
    multiLine: true,
  ).allMatches(pubspec.readAsStringSync());
  for (final entry in entries) {
    final relative = entry.group(1)!.trim();
    final path = 'apps/mobile/$relative';
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      bundled.addAll(
        Directory(path)
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => file.path.replaceAll('\\', '/')),
      );
    } else if (type == FileSystemEntityType.file) {
      bundled.add(path.replaceAll('\\', '/'));
    } else {
      failures.add('Registered Flutter asset is missing: $path');
    }
  }
  return bundled;
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
