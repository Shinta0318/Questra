import 'dart:convert';
import 'dart:io';

const defaultOutputPath = 'docs/qst/BETA_CANDIDATE.yaml';
const readinessMatrixPath = 'docs/qst/BETA_LAUNCH_READINESS.yaml';
const pubspecPath = 'apps/mobile/pubspec.yaml';

const automatedGateNames = [
  'dependency_resolution',
  'static_analysis',
  'flutter_tests',
  'rls_static_readiness',
  'performance_readiness',
  'feedback_readiness',
  'error_capture_contract',
  'privacy_copy_contract',
  'release_notes_contract',
];

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final sourceCommit =
      options.sourceCommit ?? await _git(['rev-parse', 'HEAD']);
  final rollbackCommit =
      options.rollbackCommit ?? await _git(['rev-parse', '$sourceCommit^']);
  final branch = await _git(['branch', '--show-current']);
  final version = _readAppVersion();
  final generatedAt = DateTime.now().toUtc().toIso8601String();
  final worktreeClean = await _isWorktreeClean(options.outputPath);
  final artifacts = <_ArtifactEvidence>[];

  for (final path in options.artifactPaths) {
    final file = File(path);
    artifacts.add(
      _ArtifactEvidence(
        path: path,
        exists: file.existsSync(),
        bytes: file.existsSync() ? file.lengthSync() : null,
        sha256: file.existsSync() ? await _sha256(path) : null,
      ),
    );
  }

  final checks = {
    for (final name in automatedGateNames) name: 'not_run',
    ...options.checks,
  };
  final hasArtifact = artifacts.any(
    (artifact) => artifact.exists && artifact.sha256 != null,
  );
  final automatedPassed = automatedGateNames.every(
    (name) => checks[name] == 'passed',
  );
  final distributionReady =
      options.status == 'approved' &&
      worktreeClean &&
      hasArtifact &&
      automatedPassed &&
      options.externalEvidenceComplete;

  final manifest = _buildManifest(
    status: options.status,
    distributionReady: distributionReady,
    version: version,
    sourceCommit: sourceCommit,
    rollbackCommit: rollbackCommit,
    branch: branch,
    generatedAt: generatedAt,
    worktreeClean: worktreeClean,
    checks: checks,
    artifacts: artifacts,
    externalEvidenceComplete: options.externalEvidenceComplete,
  );

  final output = File(options.outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(manifest);

  stdout.writeln('Beta candidate manifest generated: ${options.outputPath}');
  stdout.writeln('Source commit: $sourceCommit');
  stdout.writeln('Distribution ready: $distributionReady');
}

String _buildManifest({
  required String status,
  required bool distributionReady,
  required String version,
  required String sourceCommit,
  required String rollbackCommit,
  required String branch,
  required String generatedAt,
  required bool worktreeClean,
  required Map<String, String> checks,
  required List<_ArtifactEvidence> artifacts,
  required bool externalEvidenceComplete,
}) {
  final buffer = StringBuffer()
    ..writeln('version: 1')
    ..writeln('candidate_status: ${_yaml(status)}')
    ..writeln('distribution_ready: $distributionReady')
    ..writeln('app_version: ${_yaml(version)}')
    ..writeln('source_commit: ${_yaml(sourceCommit)}')
    ..writeln('rollback_commit: ${_yaml(rollbackCommit)}')
    ..writeln('branch: ${_yaml(branch)}')
    ..writeln('generated_at_utc: ${_yaml(generatedAt)}')
    ..writeln('worktree_clean_before_manifest: $worktreeClean')
    ..writeln('readiness_matrix: ${_yaml(readinessMatrixPath)}')
    ..writeln('automated_gates:');

  for (final name in automatedGateNames) {
    buffer.writeln('  $name: ${_yaml(checks[name] ?? 'not_run')}');
  }

  buffer
    ..writeln('external_evidence:')
    ..writeln('  complete: $externalEvidenceComplete')
    ..writeln(
      '  status: ${_yaml(externalEvidenceComplete ? 'verified' : 'evidence_missing')}',
    )
    ..writeln('  required_groups:')
    ..writeln('    - supabase_project_and_migrations')
    ..writeln('    - dual_account_persistence_and_rls')
    ..writeln('    - real_device_validation')
    ..writeln('    - support_operations')
    ..writeln('    - legal_sign_off')
    ..writeln('artifacts:');

  if (artifacts.isEmpty) {
    buffer
      ..writeln('  - status: not_built')
      ..writeln('    path: null')
      ..writeln('    sha256: null');
  } else {
    for (final artifact in artifacts) {
      buffer
        ..writeln('  - status: ${artifact.exists ? 'found' : 'missing'}')
        ..writeln('    path: ${_yaml(artifact.path)}')
        ..writeln('    bytes: ${artifact.bytes ?? 'null'}')
        ..writeln(
          '    sha256: ${artifact.sha256 == null ? 'null' : _yaml(artifact.sha256!)}',
        );
    }
  }

  buffer
    ..writeln('guardrails:')
    ..writeln('  local_fallback_is_cloud_evidence: false')
    ..writeln('  automated_checks_replace_external_evidence: false')
    ..writeln('  approved_requires_artifact_checksum: true')
    ..writeln('  approved_requires_clean_worktree: true');
  return buffer.toString();
}

String _readAppVersion() {
  final file = File(pubspecPath);
  if (!file.existsSync()) {
    throw StateError('Missing Flutter pubspec: $pubspecPath');
  }
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(file.readAsStringSync());
  if (match == null) {
    throw StateError('Missing version in $pubspecPath');
  }
  return match.group(1)!;
}

Future<bool> _isWorktreeClean(String outputPath) async {
  final result = await Process.run('git', ['status', '--porcelain']);
  if (result.exitCode != 0) {
    throw StateError('Unable to inspect git worktree: ${result.stderr}');
  }
  final normalizedOutput = outputPath.replaceAll('\\', '/');
  final relevant = LineSplitter.split(result.stdout as String).where((line) {
    final path = line.length > 3 ? line.substring(3).trim() : line.trim();
    final normalized = path.replaceAll('\\', '/');
    return normalized != normalizedOutput && !normalized.startsWith('.idea/');
  });
  return relevant.isEmpty;
}

Future<String> _git(List<String> arguments) async {
  final result = await Process.run('git', arguments);
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

Future<String?> _sha256(String path) async {
  final command = Platform.isWindows ? 'certutil' : 'sha256sum';
  final arguments = Platform.isWindows ? ['-hashfile', path, 'SHA256'] : [path];
  final result = await Process.run(command, arguments);
  if (result.exitCode != 0) {
    return null;
  }
  return RegExp(
    r'\b[a-fA-F0-9]{64}\b',
  ).firstMatch(result.stdout as String)?.group(0)?.toLowerCase();
}

String _yaml(String value) => jsonEncode(value);

class _ArtifactEvidence {
  const _ArtifactEvidence({
    required this.path,
    required this.exists,
    required this.bytes,
    required this.sha256,
  });

  final String path;
  final bool exists;
  final int? bytes;
  final String? sha256;
}

class _Options {
  const _Options({
    required this.outputPath,
    required this.status,
    required this.sourceCommit,
    required this.rollbackCommit,
    required this.artifactPaths,
    required this.checks,
    required this.externalEvidenceComplete,
  });

  final String outputPath;
  final String status;
  final String? sourceCommit;
  final String? rollbackCommit;
  final List<String> artifactPaths;
  final Map<String, String> checks;
  final bool externalEvidenceComplete;

  static _Options parse(List<String> arguments) {
    var outputPath = defaultOutputPath;
    var status = 'draft';
    String? sourceCommit;
    String? rollbackCommit;
    var externalEvidenceComplete = false;
    final artifacts = <String>[];
    final checks = <String, String>{};

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      String nextValue() {
        if (index + 1 >= arguments.length) {
          throw ArgumentError('Missing value after $argument');
        }
        return arguments[++index];
      }

      switch (argument) {
        case '--output':
          outputPath = nextValue();
        case '--status':
          status = nextValue();
        case '--source-commit':
          sourceCommit = nextValue();
        case '--rollback-commit':
          rollbackCommit = nextValue();
        case '--artifact':
          artifacts.add(nextValue());
        case '--check':
          final value = nextValue();
          final separator = value.indexOf('=');
          if (separator <= 0 || separator == value.length - 1) {
            throw ArgumentError('Use --check name=status.');
          }
          final name = value.substring(0, separator);
          if (!automatedGateNames.contains(name)) {
            throw ArgumentError('Unknown automated gate: $name');
          }
          checks[name] = value.substring(separator + 1);
        case '--external-evidence-complete':
          externalEvidenceComplete = true;
        default:
          throw ArgumentError('Unknown option: $argument');
      }
    }

    const allowedStatuses = {'draft', 'validated', 'approved'};
    if (!allowedStatuses.contains(status)) {
      throw ArgumentError('Status must be draft, validated, or approved.');
    }
    return _Options(
      outputPath: outputPath,
      status: status,
      sourceCommit: sourceCommit,
      rollbackCommit: rollbackCommit,
      artifactPaths: artifacts,
      checks: checks,
      externalEvidenceComplete: externalEvidenceComplete,
    );
  }
}
