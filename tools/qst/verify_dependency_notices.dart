import 'dart:convert';
import 'dart:io';

const manifestPath = 'docs/qst/DEPENDENCY_LICENSE_MANIFEST.yaml';
const noticePath = 'docs/legal/THIRD_PARTY_NOTICES.md';
const registryPath = 'tools/qst/server_dependency_registry.json';
const functionsPath = 'supabase/functions';

Future<void> main(List<String> arguments) async {
  final requireRelease = arguments.contains('--require-release');
  final manifest = _read(manifestPath);
  final notice = _read(noticePath);
  for (final required in [
    'missing_license_release_allowed: false',
    'unpinned_server_dependency_release_allowed: false',
    'generated_notice_is_legal_approval: false',
    'package_presence_proves_permitted_use: false',
  ]) {
    if (!manifest.contains(required)) _fail('Missing guardrail: $required');
  }
  final packages = _lockPackageNames();
  for (final package in packages) {
    if (!notice.contains('- $package ')) {
      _fail('Notice is missing resolved package: $package');
    }
  }
  if (!manifest.contains('flutter_dart_package_count: ${packages.length}')) {
    _fail('Dependency manifest package count is stale.');
  }

  final imports = _npmImports();
  final registry = jsonDecode(_read(registryPath)) as Map;
  final entries = (registry['dependencies'] as List)
      .map((raw) => Map<String, dynamic>.from(raw as Map))
      .toList();
  if (!manifest.contains('npm_import_count: ${imports.length}')) {
    _fail('Dependency manifest npm import count is stale.');
  }
  for (final specifier in imports) {
    if (!_isExactlyPinned(specifier)) {
      _fail('Server dependency is not exactly pinned: $specifier');
    }
    final matches = entries.where((entry) => entry['specifier'] == specifier);
    if (matches.length != 1) {
      _fail('Server dependency must have one registry entry: $specifier');
    }
    final entry = matches.single;
    for (final key in [
      'registryUrl',
      'license',
      'licenseFile',
      'licenseSha256',
      'distributionIntegrity',
      'distributionShasum',
      'metadataRetrievedAtUtc',
    ]) {
      final value = entry[key]?.toString().trim() ?? '';
      if (value.isEmpty || value == 'pending' || value == 'missing') {
        _fail('Server registry entry lacks $key for $specifier.');
      }
    }
    final licenseFile = entry['licenseFile'] as String;
    final expectedHash = entry['licenseSha256'] as String;
    if (!File(licenseFile).existsSync()) {
      _fail('Registered server license file is missing: $licenseFile');
    }
    if (await _sha256(licenseFile) != expectedHash) {
      _fail('Server license hash mismatch for $specifier.');
    }
    for (final expected in [
      specifier,
      expectedHash,
      entry['distributionIntegrity'] as String,
    ]) {
      if (!manifest.contains(expected) && !notice.contains(expected)) {
        _fail('Dependency evidence does not contain $expected.');
      }
    }
  }
  if (entries.any((entry) => !imports.contains(entry['specifier']))) {
    _fail('Server dependency registry contains unused entries.');
  }
  for (final required in [
    'missing_license_file_count: 0',
    'unpinned_npm_import_count: 0',
    'unregistered_npm_import_count: 0',
    'stale_server_registry_entry_count: 0',
  ]) {
    if (!manifest.contains(required))
      _fail('Dependency gate missing: $required');
  }

  final head = (await Process.run('git', [
    'rev-parse',
    'HEAD',
  ])).stdout.toString().trim();
  if (!manifest.contains('candidate_source_commit: "$head"')) {
    _fail('Dependency evidence is not bound to current HEAD.');
  }
  if (requireRelease) {
    for (final required in [
      'status: approved',
      'product_owner_approval: approved',
      'legal_reviewer_approval: approved',
    ]) {
      if (!manifest.contains(required)) {
        _fail('Release notice gate missing: $required');
      }
    }
  }
  stdout.writeln(
    requireRelease
        ? 'Dependency release notices verification passed.'
        : 'Dependency inventory, exact server pins, registry evidence, and hashes passed; human review may remain pending.',
  );
}

Set<String> _npmImports() {
  final imports = <String>{};
  for (final file
      in Directory(functionsPath)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.ts'))) {
    imports.addAll(
      RegExp(
        r'''["'](npm:[^"']+)["']''',
      ).allMatches(file.readAsStringSync()).map((match) => match.group(1)!),
    );
  }
  return imports;
}

bool _isExactlyPinned(String specifier) =>
    RegExp(r'@(\d+\.\d+\.\d+)(?:["/]|$)').hasMatch(specifier);

Future<String> _sha256(String path) async {
  final result = Platform.isWindows
      ? await Process.run('certutil', ['-hashfile', path, 'SHA256'])
      : await Process.run('sha256sum', [path]);
  if (result.exitCode != 0) _fail('Unable to hash $path.');
  final match = RegExp(
    r'([a-fA-F0-9]{64})',
  ).firstMatch(result.stdout.toString());
  if (match == null) _fail('Hash output was invalid for $path.');
  return match.group(1)!.toLowerCase();
}

Set<String> _lockPackageNames() {
  return RegExp(r'^  ([a-zA-Z0-9_]+):$', multiLine: true)
      .allMatches(_read('apps/mobile/pubspec.lock'))
      .map((match) => match.group(1)!)
      .where((name) => name != 'questra')
      .toSet();
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing required file: $path');
  return file.readAsStringSync();
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
