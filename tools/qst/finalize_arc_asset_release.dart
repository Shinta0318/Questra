import 'dart:convert';
import 'dart:io';

const provenancePath = 'docs/qst/ARC_ASSET_PROVENANCE.yaml';
const packagePath = 'docs/qst/CANDIDATE_ASSET_PACKAGE.yaml';
const decisionPath = 'docs/qst/ARC_ASSET_RELEASE_DECISION.yaml';
const recordDirectory = 'docs/qst/arc_asset_chain_of_title';
const candidatePath = 'docs/qst/BETA_CANDIDATE.yaml';
const expectedBranch = 'codex/initial-questra-structure-pr';

const runtimeAssetNames = <String>[
  'arc_celebrate.png',
  'arc_excited.png',
  'arc_lonely.png',
  'arc_normal.png',
  'arc_serious.png',
  'arc_support.png',
  'arc_worried.png',
];

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final head = _command(['git', 'rev-parse', 'HEAD']).trim();
  final branch = _command(['git', 'branch', '--show-current']).trim();
  if (branch != expectedBranch) _fail('Arc release must use $expectedBranch.');
  if (options.candidateSha != head) _fail('Candidate SHA does not match HEAD.');
  if (_command(['git', 'status', '--porcelain']).trim().isNotEmpty) {
    _fail('Arc release evidence must start from a clean worktree.');
  }
  if (!_read(candidatePath).contains('source_commit: "$head"')) {
    _fail('Beta candidate manifest is not bound to HEAD.');
  }

  final previousProvenance = _read(provenancePath);
  final previousPackage = _read(packagePath);
  final previousDecision = _read(decisionPath);
  final previousHashes = _manifestHashes(previousProvenance);
  final runtimeAssets = await _runtimeAssets();
  final changedHashes = runtimeAssets
      .where((asset) => previousHashes[asset.path] != asset.sha256)
      .length;
  if (options.route == 'current_provenance' && changedHashes != 0) {
    _fail('Current-provenance route cannot accept changed asset bytes.');
  }
  if (options.route == 'release_safe_replacement' && changedHashes == 0) {
    _fail('Replacement route requires at least one new asset hash.');
  }

  for (final asset in runtimeAssets) {
    _validateRecord(asset);
  }

  final now = DateTime.now().toUtc().toIso8601String();
  final references =
      Directory('apps/mobile/assets/mockups')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path.replaceAll('\\', '/'))
          .toList()
        ..sort();
  final provenance = await _provenance(
    head: head,
    runtimeAssets: runtimeAssets,
    references: references,
  );
  final package = _package(
    head: head,
    runtimeAssets: runtimeAssets,
    references: references,
  );
  final decision = _decision(
    head: head,
    route: options.route,
    appliedAt: now,
    changedHashes: changedHashes,
  );

  try {
    File(provenancePath).writeAsStringSync(provenance);
    File(packagePath).writeAsStringSync(package);
    File(decisionPath).writeAsStringSync(decision);
    _runVerifier('tools/qst/verify_arc_asset_provenance.dart');
    _runVerifier('tools/qst/verify_candidate_asset_package.dart');
  } catch (error) {
    File(provenancePath).writeAsStringSync(previousProvenance);
    File(packagePath).writeAsStringSync(previousPackage);
    File(decisionPath).writeAsStringSync(previousDecision);
    _fail(
      'Arc release apply failed and previous manifests were restored: $error',
    );
  }
  stdout.writeln(
    'Arc release manifests prepared for $head via ${options.route}; '
    'run the strict release gate before distribution.',
  );
}

Future<List<_Asset>> _runtimeAssets() async {
  const root = 'apps/mobile/assets/characters/arc';
  final actualNames = Directory(root)
      .listSync()
      .whereType<File>()
      .map((file) => file.uri.pathSegments.last)
      .toSet();
  if (actualNames.length != runtimeAssetNames.length ||
      !actualNames.containsAll(runtimeAssetNames)) {
    _fail(
      'Arc runtime directory must contain exactly the approved seven names.',
    );
  }
  final assets = <_Asset>[];
  for (final name in runtimeAssetNames) {
    final path = '$root/$name';
    assets.add(
      _Asset(
        path: path,
        bytes: File(path).lengthSync(),
        sha256: await _sha256(path),
      ),
    );
  }
  return assets;
}

void _validateRecord(_Asset asset) {
  final record = File('$recordDirectory/${asset.sha256}.json');
  if (!record.existsSync()) _fail('Missing chain record for ${asset.path}.');
  final decoded = jsonDecode(record.readAsStringSync());
  if (decoded is! Map) _fail('Chain record must be an object: ${record.path}');
  final data = Map<String, dynamic>.from(decoded);
  if (data['schemaVersion'] != 1 ||
      data['assetPath'] != asset.path ||
      data['assetSha256'] != asset.sha256 ||
      data['commercialDistributionAllowed'] != true ||
      data['productDecision'] != 'approved' ||
      data['legalDecision'] != 'approved') {
    _fail('Chain record is not release-complete: ${asset.path}');
  }
  for (final field in const [
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
    final value = data[field]?.toString().trim() ?? '';
    if (value.isEmpty || value == 'pending') {
      _fail('Chain record lacks $field: ${asset.path}');
    }
  }
  final usage = data['reviewedUsage'];
  if (usage is! List || usage.isEmpty) {
    _fail('Chain record lacks reviewedUsage: ${asset.path}');
  }
}

Future<String> _provenance({
  required String head,
  required List<_Asset> runtimeAssets,
  required List<String> references,
}) async {
  final output = StringBuffer()
    ..writeln('version: 1')
    ..writeln('status: approved')
    ..writeln('updated_at: "${DateTime.now().toUtc().toIso8601String()}"')
    ..writeln('candidate_source_commit: "$head"')
    ..writeln('chain_of_title_record_directory: "$recordDirectory"')
    ..writeln('product_owner_approval: approved')
    ..writeln('legal_reviewer_approval: approved')
    ..writeln('chain_of_title_complete: true')
    ..writeln('assets:');
  for (final asset in runtimeAssets) {
    _writeAsset(output, asset, 'runtime', 'chain_of_title_reviewed', true);
  }
  for (final path in references) {
    final asset = _Asset(
      path: path,
      bytes: File(path).lengthSync(),
      sha256: await _sha256(path),
    );
    _writeAsset(output, asset, 'repository_reference', 'reference_only', false);
  }
  output
    ..writeln('guardrails:')
    ..writeln('  missing_asset_allowed: false')
    ..writeln('  hash_mismatch_allowed: false')
    ..writeln('  untracked_bundled_asset_allowed: false')
    ..writeln('  unverified_asset_public_release_allowed: false')
    ..writeln('  repository_presence_proves_ownership: false')
    ..writeln('  reference_asset_in_candidate_allowed: false')
    ..writeln('  hash_change_preserves_approval: false')
    ..writeln('  approval_without_source_record_allowed: false')
    ..writeln('  unreviewed_chain_record_release_allowed: false')
    ..writeln('  record_asset_hash_mismatch_allowed: false')
    ..writeln('  secret_or_raw_signature_in_record_allowed: false');
  return output.toString();
}

String _package({
  required String head,
  required List<_Asset> runtimeAssets,
  required List<String> references,
}) {
  final output = StringBuffer()
    ..writeln('version: 1')
    ..writeln('status: approved')
    ..writeln('candidate_source_commit: "$head"')
    ..writeln('working_tree_clean_at_generation: true')
    ..writeln('release_ready: true')
    ..writeln('runtime_asset_count: ${runtimeAssets.length}')
    ..writeln('repository_reference_asset_count: ${references.length}')
    ..writeln('runtime_assets:');
  for (final asset in runtimeAssets) {
    output
      ..writeln('  - path: "${asset.path}"')
      ..writeln('    bytes: ${asset.bytes}')
      ..writeln('    sha256: "${asset.sha256}"')
      ..writeln('    provenance: chain_of_title_reviewed')
      ..writeln('    release_allowed: true');
  }
  output.writeln('excluded_repository_references:');
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
  return output.toString();
}

String _decision({
  required String head,
  required String route,
  required String appliedAt,
  required int changedHashes,
}) =>
    '''version: 1
qst: QST-399
status: approved
candidate_source_commit: "$head"
working_tree_clean_before_apply: true
decision_route: $route
runtime_asset_count: 7
approved_runtime_asset_count: 7
changed_runtime_asset_count: $changedHashes
applied_at_utc: "$appliedAt"
guardrails:
  complete_set_required: true
  chain_record_per_runtime_asset_required: true
  exact_hash_match_required: true
  product_and_legal_approval_required: true
  commercial_distribution_permission_required: true
  partial_approval_allowed: false
  replacement_without_hash_change_allowed: false
  current_asset_hash_change_allowed: false
  reference_mockup_bundled: false
  failed_apply_restores_previous_manifests: true
  repository_presence_proves_ownership: false
  visual_approval_proves_distribution_rights: false
''';

void _writeAsset(
  StringBuffer output,
  _Asset asset,
  String usage,
  String provenance,
  bool releaseAllowed,
) {
  output
    ..writeln('  - path: "${asset.path}"')
    ..writeln('    bytes: ${asset.bytes}')
    ..writeln('    sha256: "${asset.sha256}"')
    ..writeln('    usage: $usage')
    ..writeln('    provenance: $provenance')
    ..writeln('    release_allowed: $releaseAllowed');
}

Map<String, String> _manifestHashes(String content) => {
  for (final match in RegExp(
    r'  - path: "([^"]+)"\r?\n'
    r'    bytes: \d+\r?\n'
    r'    sha256: "([a-f0-9]{64})"',
  ).allMatches(content))
    match.group(1)!: match.group(2)!,
};

void _runVerifier(String path) {
  final result = Process.runSync('dart', ['run', path, '--require-release']);
  if (result.exitCode != 0) {
    throw StateError(result.stderr.toString().trim());
  }
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing $path');
  return file.readAsStringSync();
}

String _command(List<String> command) {
  final result = Process.runSync(command.first, command.skip(1).toList());
  if (result.exitCode != 0) _fail(result.stderr.toString());
  return result.stdout.toString();
}

Future<String> _sha256(String path) async {
  final command = Platform.isWindows ? 'certutil' : 'sha256sum';
  final args = Platform.isWindows ? ['-hashfile', path, 'SHA256'] : [path];
  final result = await Process.run(command, args);
  if (result.exitCode != 0) _fail('Unable to hash $path.');
  final hash = RegExp(
    r'\b[a-fA-F0-9]{64}\b',
  ).firstMatch(result.stdout.toString())?.group(0)?.toLowerCase();
  if (hash == null) _fail('Invalid hash output for $path.');
  return hash;
}

class _Options {
  const _Options({required this.candidateSha, required this.route});

  final String candidateSha;
  final String route;

  factory _Options.parse(List<String> arguments) {
    final values = <String, String>{};
    for (final argument in arguments) {
      final separator = argument.indexOf('=');
      if (!argument.startsWith('--') || separator < 3) continue;
      values[argument.substring(2, separator)] = argument.substring(
        separator + 1,
      );
    }
    if (values['confirm-apply'] != 'true') {
      _fail('Explicit --confirm-apply=true is required.');
    }
    final candidateSha = values['candidate-sha']?.trim() ?? '';
    if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(candidateSha)) {
      _fail('A full 40-character --candidate-sha is required.');
    }
    final route = values['route'];
    if (route != 'current_provenance' && route != 'release_safe_replacement') {
      _fail('--route must be current_provenance or release_safe_replacement.');
    }
    return _Options(candidateSha: candidateSha, route: route!);
  }
}

class _Asset {
  const _Asset({required this.path, required this.bytes, required this.sha256});

  final String path;
  final int bytes;
  final String sha256;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
