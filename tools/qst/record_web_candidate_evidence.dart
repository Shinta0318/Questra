import 'dart:io';

const outputPath = 'docs/qst/WEB_CANDIDATE_SESSION.yaml';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final head = _command(['git', 'rev-parse', 'HEAD']).trim();
  if (_command(['git', 'status', '--porcelain']).trim().isNotEmpty) {
    _fail('Web evidence must be recorded from a clean worktree.');
  }
  if (options.candidateSha != head) {
    _fail('Candidate SHA does not match HEAD.');
  }
  if (!{'chrome', 'edge'}.contains(options.browserFamily)) {
    _fail('Supported Web evidence requires Chrome or Edge.');
  }
  if (!options.supabaseConnected || !options.serverAiConnected) {
    _fail('Supported Web evidence requires hosted Supabase and server AI.');
  }
  if (options.mockPersistence) {
    _fail('Mock persistence cannot be recorded as supported Web evidence.');
  }
  if (!options.privacyReviewed) {
    _fail('Evidence requires explicit privacy review confirmation.');
  }
  final candidate = File('docs/qst/BETA_CANDIDATE.yaml').readAsStringSync();
  if (!candidate.contains('source_commit: "$head"')) {
    _fail('Beta candidate manifest does not match HEAD.');
  }

  final artifact = await _evidenceFile(
    options.artifactPath,
    requiredRoot: 'artifacts/candidate/',
  );
  final evidence = <String, _EvidenceFile>{};
  for (final entry in options.evidence.entries) {
    evidence[entry.key] = await _evidenceFile(
      entry.value,
      requiredRoot: 'artifacts/qst396/',
    );
  }

  final output = StringBuffer()
    ..writeln('version: 1')
    ..writeln('qst: QST-396')
    ..writeln('status: verified')
    ..writeln('candidate_sha: "${options.candidateSha}"')
    ..writeln('working_tree_clean_at_execution: true')
    ..writeln('executed_at_utc: "${DateTime.now().toUtc().toIso8601String()}"')
    ..writeln('tester_role: "${_yaml(options.testerRole)}"')
    ..writeln('environment:')
    ..writeln('  browser_family: "${options.browserFamily}"')
    ..writeln('  browser_version: "${_yaml(options.browserVersion)}"')
    ..writeln('  operating_system: "${_yaml(options.operatingSystem)}"')
    ..writeln('  supabase_connected: true')
    ..writeln('  server_ai_connected: true')
    ..writeln('  mock_persistence: false')
    ..writeln('artifact:')
    ..writeln('  path: "${artifact.path}"')
    ..writeln('  bytes: ${artifact.bytes}')
    ..writeln('  sha256: "${artifact.sha256}"')
    ..writeln('checks:');
  for (final name in _Options.requiredEvidence) {
    output.writeln('  $name: passed');
  }
  output.writeln('evidence:');
  for (final entry in evidence.entries) {
    output
      ..writeln('  - check: ${entry.key}')
      ..writeln('    path: "${entry.value.path}"')
      ..writeln('    bytes: ${entry.value.bytes}')
      ..writeln('    sha256: "${entry.value.sha256}"');
  }
  output
    ..writeln('guardrails:')
    ..writeln('  privacy_reviewed: true')
    ..writeln('  credential_or_token_recorded: false')
    ..writeln('  account_identifier_recorded: false')
    ..writeln('  private_journey_content_recorded: false')
    ..writeln('  mock_server_is_supported_web_evidence: false')
    ..writeln('  automated_test_replaces_human_evidence: false')
    ..writeln('  artifact_content_committed: false');
  File(outputPath).writeAsStringSync(output.toString());
  stdout.writeln('Supported Web evidence recorded for $head.');
}

class _Options {
  const _Options({
    required this.candidateSha,
    required this.testerRole,
    required this.browserFamily,
    required this.browserVersion,
    required this.operatingSystem,
    required this.artifactPath,
    required this.supabaseConnected,
    required this.serverAiConnected,
    required this.mockPersistence,
    required this.privacyReviewed,
    required this.evidence,
  });

  static const requiredEvidence = [
    'launch',
    'login',
    'quest_mission_task_trail',
    'arc',
    'japanese_ime',
    'keyboard',
    'responsive',
  ];

  final String candidateSha;
  final String testerRole;
  final String browserFamily;
  final String browserVersion;
  final String operatingSystem;
  final String artifactPath;
  final bool supabaseConnected;
  final bool serverAiConnected;
  final bool mockPersistence;
  final bool privacyReviewed;
  final Map<String, String> evidence;

  factory _Options.parse(List<String> arguments) {
    final values = <String, String>{};
    for (final argument in arguments) {
      final separator = argument.indexOf('=');
      if (!argument.startsWith('--') || separator < 3) continue;
      values[argument.substring(2, separator)] = argument.substring(
        separator + 1,
      );
    }
    for (final key in [
      'candidate-sha',
      'tester-role',
      'browser-family',
      'browser-version',
      'operating-system',
      'artifact',
    ]) {
      if ((values[key] ?? '').trim().isEmpty) _fail('Missing required --$key.');
    }
    final evidence = <String, String>{};
    for (final key in requiredEvidence) {
      final value = values[key];
      if (value == null || value.trim().isEmpty) {
        _fail('Missing required --$key=<evidence path>.');
      }
      evidence[key] = value;
    }
    return _Options(
      candidateSha: values['candidate-sha']!,
      testerRole: values['tester-role']!,
      browserFamily: values['browser-family']!.trim().toLowerCase(),
      browserVersion: values['browser-version']!,
      operatingSystem: values['operating-system']!,
      artifactPath: values['artifact']!,
      supabaseConnected: values['supabase-connected'] == 'true',
      serverAiConnected: values['server-ai-connected'] == 'true',
      mockPersistence: values['mock-persistence'] == 'true',
      privacyReviewed: values['privacy-reviewed'] == 'true',
      evidence: evidence,
    );
  }
}

class _EvidenceFile {
  const _EvidenceFile(this.path, this.bytes, this.sha256);

  final String path;
  final int bytes;
  final String sha256;
}

Future<_EvidenceFile> _evidenceFile(
  String rawPath, {
  required String requiredRoot,
}) async {
  final path = rawPath.replaceAll('\\', '/');
  if (!path.startsWith(requiredRoot)) {
    _fail('Evidence must be under $requiredRoot: $path');
  }
  final file = File(path);
  if (!file.existsSync() || file.lengthSync() == 0) {
    _fail('Evidence file is missing or empty: $path');
  }
  final hash = await _sha256(path);
  if (hash == null) _fail('Unable to hash $path');
  return _EvidenceFile(path, file.lengthSync(), hash);
}

String _command(List<String> command) {
  final result = Process.runSync(command.first, command.skip(1).toList());
  if (result.exitCode != 0) _fail(result.stderr.toString());
  return result.stdout.toString();
}

Future<String?> _sha256(String path) async {
  final command = Platform.isWindows ? 'certutil' : 'sha256sum';
  final arguments = Platform.isWindows ? ['-hashfile', path, 'SHA256'] : [path];
  final result = await Process.run(command, arguments);
  if (result.exitCode != 0) return null;
  return RegExp(
    r'\b[a-fA-F0-9]{64}\b',
  ).firstMatch(result.stdout.toString())?.group(0)?.toLowerCase();
}

String _yaml(String value) => value.replaceAll('"', '\\"');

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
