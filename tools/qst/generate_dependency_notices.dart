import 'dart:convert';
import 'dart:io';

const packageConfigPath = 'apps/mobile/.dart_tool/package_config.json';
const lockPath = 'apps/mobile/pubspec.lock';
const functionsPath = 'supabase/functions';
const noticePath = 'docs/legal/THIRD_PARTY_NOTICES.md';
const manifestPath = 'docs/qst/DEPENDENCY_LICENSE_MANIFEST.yaml';
const serverRegistryPath = 'tools/qst/server_dependency_registry.json';

Future<void> main() async {
  final config = jsonDecode(File(packageConfigPath).readAsStringSync()) as Map;
  final versions = _lockVersions(File(lockPath).readAsLinesSync());
  final pending = <_PendingPackage>[];
  for (final raw in config['packages'] as List) {
    final entry = Map<String, dynamic>.from(raw as Map);
    final name = entry['name'] as String;
    if (name == 'questra') continue;
    final rootUri = Uri.parse(entry['rootUri'] as String);
    if (rootUri.scheme != 'file') continue;
    final root = Directory(rootUri.toFilePath(windows: Platform.isWindows));
    final version = versions[name] ?? 'sdk';
    pending.add(
      _PendingPackage(
        name: name,
        version: version,
        license: _findLicense(root),
      ),
    );
  }
  final hashes = await _sha256Many(
    pending
        .map((item) => item.license?.absolute.path)
        .whereType<String>()
        .toSet()
        .toList(),
  );
  final packages = pending
      .map(
        (item) => _PackageLicense(
          name: item.name,
          version: item.version,
          licenseFile: item.license?.uri.pathSegments.last,
          licenseText: item.license?.readAsStringSync(),
          sha256: item.license == null
              ? null
              : hashes[_normalizedPath(item.license!.absolute.path)],
        ),
      )
      .toList();
  packages.sort((a, b) => a.name.compareTo(b.name));
  final npmImports = _npmImports();
  final serverDependencies = _serverDependencies();
  final serverLicenseHashes = await _sha256Many(
    serverDependencies.map((item) => item.licenseFile).toSet().toList(),
  );
  final missing = packages.where((item) => item.licenseText == null).length;
  final unpinnedNpm = npmImports
      .where((item) => !_isExactlyPinned(item))
      .length;
  final unregisteredNpm = npmImports
      .where(
        (specifier) => !serverDependencies.any(
          (dependency) => dependency.specifier == specifier,
        ),
      )
      .length;
  final staleRegistryEntries = serverDependencies.where((dependency) {
    final actual = serverLicenseHashes[_normalizedPath(dependency.licenseFile)];
    return !npmImports.contains(dependency.specifier) ||
        actual == null ||
        actual != dependency.licenseSha256;
  }).length;
  final sha = (await Process.run('git', [
    'rev-parse',
    'HEAD',
  ])).stdout.toString().trim();
  final generatedAt = DateTime.now().toUtc().toIso8601String();
  final status =
      missing == 0 &&
          unpinnedNpm == 0 &&
          unregisteredNpm == 0 &&
          staleRegistryEntries == 0
      ? 'generated_review_pending'
      : 'blocked_dependency_evidence_incomplete';

  final notice = StringBuffer()
    ..writeln('# Third-Party Notices')
    ..writeln()
    ..writeln('Generated: $generatedAt  ')
    ..writeln('Candidate source commit: `$sha`')
    ..writeln()
    ..writeln(
      'This inventory reproduces license files available in the resolved Flutter/Dart package graph. Absence from this file is not a legal conclusion.',
    )
    ..writeln()
    ..writeln('## Resolved package inventory')
    ..writeln();
  for (final package in packages) {
    notice..writeln(
      '- ${package.name} ${package.version} - `${package.licenseFile ?? 'missing'}` - `${package.sha256 ?? 'missing'}`',
    );
  }
  final licenseGroups = <String, List<_PackageLicense>>{};
  for (final package in packages.where((item) => item.sha256 != null)) {
    licenseGroups.putIfAbsent(package.sha256!, () => []).add(package);
  }
  notice
    ..writeln()
    ..writeln('## Unique license texts')
    ..writeln();
  for (final entry in licenseGroups.entries) {
    final packageNames = entry.value
        .map((item) => '${item.name} ${item.version}')
        .join(', ');
    notice
      ..writeln('### ${entry.key}')
      ..writeln()
      ..writeln('Packages: $packageNames')
      ..writeln()
      ..writeln('```text')
      ..writeln(entry.value.first.licenseText!.trim())
      ..writeln('```')
      ..writeln();
  }
  if (npmImports.isNotEmpty) {
    notice
      ..writeln('## Supabase Edge Function npm imports')
      ..writeln();
    for (final dependency in serverDependencies) {
      if (!npmImports.contains(dependency.specifier)) continue;
      notice
        ..writeln('### `${dependency.specifier}`')
        ..writeln()
        ..writeln('- Registry metadata: ${dependency.registryUrl}')
        ..writeln('- Declared license: `${dependency.license}`')
        ..writeln('- License SHA-256: `${dependency.licenseSha256}`')
        ..writeln(
          '- Distribution integrity: `${dependency.distributionIntegrity}`',
        )
        ..writeln('- Distribution SHA-1: `${dependency.distributionShasum}`')
        ..writeln(
          '- Metadata retrieved: `${dependency.metadataRetrievedAtUtc}`',
        )
        ..writeln()
        ..writeln('```text')
        ..writeln(File(dependency.licenseFile).readAsStringSync().trim())
        ..writeln('```')
        ..writeln();
    }
  }
  File(noticePath).writeAsStringSync(notice.toString());

  final manifest = StringBuffer()
    ..writeln('version: 1')
    ..writeln('status: $status')
    ..writeln('generated_at_utc: "$generatedAt"')
    ..writeln('candidate_source_commit: "$sha"')
    ..writeln('flutter_dart_package_count: ${packages.length}')
    ..writeln('missing_license_file_count: $missing')
    ..writeln('npm_import_count: ${npmImports.length}')
    ..writeln('unpinned_npm_import_count: $unpinnedNpm')
    ..writeln('unregistered_npm_import_count: $unregisteredNpm')
    ..writeln('stale_server_registry_entry_count: $staleRegistryEntries')
    ..writeln('server_dependency_registry: $serverRegistryPath')
    ..writeln('product_owner_approval: pending')
    ..writeln('legal_reviewer_approval: pending')
    ..writeln('notice_file: $noticePath')
    ..writeln('npm_imports:');
  if (npmImports.isEmpty) {
    manifest.writeln('  []');
  } else {
    for (final specifier in npmImports) {
      final matches = serverDependencies.where(
        (dependency) => dependency.specifier == specifier,
      );
      final dependency = matches.isEmpty ? null : matches.single;
      manifest
        ..writeln('  - specifier: "$specifier"')
        ..writeln('    exact_version_pinned: ${_isExactlyPinned(specifier)}')
        ..writeln('    registry_recorded: ${dependency != null}')
        ..writeln(
          '    license_sha256: "${dependency?.licenseSha256 ?? 'missing'}"',
        )
        ..writeln(
          '    distribution_integrity: "${dependency?.distributionIntegrity ?? 'missing'}"',
        )
        ..writeln('    license_review: pending');
    }
  }
  manifest
    ..writeln('guardrails:')
    ..writeln('  missing_license_release_allowed: false')
    ..writeln('  unpinned_server_dependency_release_allowed: false')
    ..writeln('  generated_notice_is_legal_approval: false')
    ..writeln('  package_presence_proves_permitted_use: false');
  File(manifestPath).writeAsStringSync(manifest.toString());
  stdout.writeln(
    'Dependency notices generated: ${packages.length} packages, $missing missing licenses, $unpinnedNpm unpinned npm imports, $unregisteredNpm unregistered npm imports.',
  );
}

List<_ServerDependency> _serverDependencies() {
  final decoded =
      jsonDecode(File(serverRegistryPath).readAsStringSync()) as Map;
  return (decoded['dependencies'] as List)
      .map(
        (raw) =>
            _ServerDependency.fromJson(Map<String, dynamic>.from(raw as Map)),
      )
      .toList();
}

Map<String, String> _lockVersions(List<String> lines) {
  final result = <String, String>{};
  String? current;
  for (final line in lines) {
    final package = RegExp(r'^  ([a-zA-Z0-9_]+):$').firstMatch(line);
    if (package != null) {
      current = package.group(1);
      continue;
    }
    final version = RegExp(r'^    version: "?([^"\s]+)"?$').firstMatch(line);
    if (current != null && version != null) {
      result[current] = version.group(1)!;
    }
  }
  return result;
}

File? _findLicense(Directory root) {
  var current = root;
  for (var depth = 0; depth < 4; depth++) {
    for (final name in const [
      'LICENSE',
      'LICENSE.txt',
      'LICENSE.md',
      'COPYING',
      'NOTICE',
    ]) {
      final file = File('${current.path}${Platform.pathSeparator}$name');
      if (file.existsSync()) return file;
    }
    final parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }
  return null;
}

List<String> _npmImports() {
  final imports = <String>{};
  for (final file
      in Directory(functionsPath)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.ts'))) {
    final content = file.readAsStringSync();
    imports.addAll(
      RegExp(
        r'''["'](npm:[^"']+)["']''',
      ).allMatches(content).map((match) => match.group(1)!),
    );
  }
  return imports.toList()..sort();
}

bool _isExactlyPinned(String specifier) {
  final version = RegExp(r'@(\d+\.\d+\.\d+)(?:["/]|$)').firstMatch(specifier);
  return version != null;
}

Future<Map<String, String>> _sha256Many(List<String> paths) async {
  if (paths.isEmpty) return {};
  if (Platform.isWindows) {
    final hashes = <String, String>{};
    const batchSize = 8;
    for (var start = 0; start < paths.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, paths.length);
      final batch = paths.sublist(start, end);
      final results = await Future.wait(batch.map(_sha256Windows));
      for (var index = 0; index < batch.length; index++) {
        hashes[_normalizedPath(batch[index])] = results[index];
      }
    }
    return hashes;
  }

  final result = await Process.run('sha256sum', paths);
  if (result.exitCode != 0) {
    throw StateError('Unable to hash dependency licenses: ${result.stderr}');
  }
  final hashes = <String, String>{};
  for (final line in (result.stdout as String).split(RegExp(r'\r?\n'))) {
    if (line.trim().isEmpty) continue;
    final match = RegExp(r'^([a-fA-F0-9]{64})\s+\*?(.+)$').firstMatch(line);
    if (match != null) {
      hashes[_normalizedPath(match.group(2)!)] = match.group(1)!.toLowerCase();
    }
  }
  return hashes;
}

Future<String> _sha256Windows(String path) async {
  final result = await Process.run('certutil', ['-hashfile', path, 'SHA256']);
  if (result.exitCode != 0) {
    throw StateError(
      'Unable to hash dependency license $path: ${result.stderr}',
    );
  }
  final match = RegExp(
    r'^([a-fA-F0-9]{64})\s*$',
    multiLine: true,
  ).firstMatch(result.stdout as String);
  if (match == null) {
    throw StateError('certutil returned no SHA-256 hash for $path.');
  }
  return match.group(1)!.toLowerCase();
}

String _normalizedPath(String path) =>
    File(path).absolute.path.replaceAll('\\', '/').toLowerCase();

class _PendingPackage {
  const _PendingPackage({
    required this.name,
    required this.version,
    required this.license,
  });

  final String name;
  final String version;
  final File? license;
}

class _PackageLicense {
  const _PackageLicense({
    required this.name,
    required this.version,
    required this.licenseFile,
    required this.licenseText,
    required this.sha256,
  });

  final String name;
  final String version;
  final String? licenseFile;
  final String? licenseText;
  final String? sha256;
}

class _ServerDependency {
  const _ServerDependency({
    required this.specifier,
    required this.registryUrl,
    required this.license,
    required this.licenseFile,
    required this.licenseSha256,
    required this.distributionIntegrity,
    required this.distributionShasum,
    required this.metadataRetrievedAtUtc,
  });

  factory _ServerDependency.fromJson(Map<String, dynamic> json) {
    return _ServerDependency(
      specifier: json['specifier'] as String,
      registryUrl: json['registryUrl'] as String,
      license: json['license'] as String,
      licenseFile: json['licenseFile'] as String,
      licenseSha256: json['licenseSha256'] as String,
      distributionIntegrity: json['distributionIntegrity'] as String,
      distributionShasum: json['distributionShasum'] as String,
      metadataRetrievedAtUtc: json['metadataRetrievedAtUtc'] as String,
    );
  }

  final String specifier;
  final String registryUrl;
  final String license;
  final String licenseFile;
  final String licenseSha256;
  final String distributionIntegrity;
  final String distributionShasum;
  final String metadataRetrievedAtUtc;
}
