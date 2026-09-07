import 'dart:io';

const outputPath = 'docs/qst/CANDIDATE_ASSET_PACKAGE.yaml';
const provenancePath = 'docs/qst/ARC_ASSET_PROVENANCE.yaml';

Future<void> main() async {
  final provenance = File(provenancePath).readAsStringSync();
  final bundled = _bundledAssets()..sort();
  final references =
      Directory('apps/mobile/assets/mockups')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path.replaceAll('\\', '/'))
          .toList()
        ..sort();
  final rows = <_AssetRow>[];
  for (final path in bundled) {
    final hash = await _sha256(path);
    if (hash == null) throw StateError('Unable to hash $path');
    final block = _provenanceBlock(provenance, path);
    rows.add(
      _AssetRow(
        path: path,
        bytes: File(path).lengthSync(),
        sha256: hash,
        provenance: _field(block, 'provenance') ?? 'missing',
        releaseAllowed: _field(block, 'release_allowed') == 'true',
      ),
    );
  }
  final provenanceApproved =
      _top(provenance, 'status') == 'approved' &&
      _top(provenance, 'product_owner_approval') == 'approved' &&
      _top(provenance, 'legal_reviewer_approval') == 'approved' &&
      _top(provenance, 'chain_of_title_complete') == 'true';
  final releaseReady =
      provenanceApproved && rows.every((row) => row.releaseAllowed);
  final sha = _command(['git', 'rev-parse', 'HEAD']).trim();
  final clean = _command(['git', 'status', '--porcelain']).trim().isEmpty;

  final output = StringBuffer()
    ..writeln('version: 1')
    ..writeln(
      'status: ${releaseReady ? 'approved' : 'blocked_ownership_review_pending'}',
    )
    ..writeln('candidate_source_commit: "$sha"')
    ..writeln('working_tree_clean_at_generation: $clean')
    ..writeln('release_ready: $releaseReady')
    ..writeln('runtime_asset_count: ${rows.length}')
    ..writeln('repository_reference_asset_count: ${references.length}')
    ..writeln('runtime_assets:');
  for (final row in rows) {
    output
      ..writeln('  - path: "${row.path}"')
      ..writeln('    bytes: ${row.bytes}')
      ..writeln('    sha256: "${row.sha256}"')
      ..writeln('    provenance: ${row.provenance}')
      ..writeln('    release_allowed: ${row.releaseAllowed}');
  }
  output..writeln('excluded_repository_references:');
  for (final path in references) {
    output.writeln('  - "$path"');
  }
  output
    ..writeln('guardrails:')
    ..writeln('  repository_reference_in_flutter_bundle_allowed: false')
    ..writeln('  untracked_runtime_asset_allowed: false')
    ..writeln('  hash_change_preserves_approval: false')
    ..writeln('  approval_without_source_record_allowed: false')
    ..writeln('  repository_presence_proves_ownership: false');
  File(outputPath).writeAsStringSync(output.toString());
  stdout.writeln(
    'Candidate asset package generated: ${rows.length} runtime, '
    '${references.length} repository-only, release_ready=$releaseReady.',
  );
}

List<String> _bundledAssets() {
  final pubspec = File('apps/mobile/pubspec.yaml').readAsStringSync();
  final result = <String>[];
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
      throw StateError('Registered asset is missing: $path');
    }
  }
  return result;
}

String _provenanceBlock(String content, String path) {
  final match = RegExp(
    '  - path: "${RegExp.escape(path)}"\\n([\\s\\S]*?)(?=\\n  - path:|\\nguardrails:)',
  ).firstMatch(content);
  if (match == null) throw StateError('Missing provenance entry: $path');
  return match.group(1)!;
}

String? _field(String content, String key) {
  return RegExp(
    '^    ${RegExp.escape(key)}:\\s*"?([^"\\n]+?)"?\\s*\$',
    multiLine: true,
  ).firstMatch(content)?.group(1)?.trim();
}

String? _top(String content, String key) {
  return RegExp(
    '^${RegExp.escape(key)}:\\s*"?([^"\\n]+?)"?\\s*\$',
    multiLine: true,
  ).firstMatch(content)?.group(1)?.trim();
}

String _command(List<String> command) {
  final result = Process.runSync(command.first, command.skip(1).toList());
  if (result.exitCode != 0) throw StateError(result.stderr as String);
  return result.stdout as String;
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

class _AssetRow {
  const _AssetRow({
    required this.path,
    required this.bytes,
    required this.sha256,
    required this.provenance,
    required this.releaseAllowed,
  });

  final String path;
  final int bytes;
  final String sha256;
  final String provenance;
  final bool releaseAllowed;
}
