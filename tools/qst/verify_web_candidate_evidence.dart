import 'dart:io';

const evidencePath = 'docs/qst/WEB_CANDIDATE_SESSION.yaml';

Future<void> main(List<String> arguments) async {
  final requireWeb = arguments.contains('--require-web');
  final file = File(evidencePath);
  if (!file.existsSync()) _fail('Web candidate evidence is missing.');
  final content = file.readAsStringSync().replaceAll('\r\n', '\n');
  for (final required in [
    'mock_server_is_supported_web_evidence: false',
    'automated_test_replaces_human_evidence: false',
    'credential_or_token_recorded: false',
    'account_identifier_recorded: false',
    'private_journey_content_recorded: false',
    'artifact_content_committed: false',
  ]) {
    _expect(content, required);
  }
  if (!requireWeb) {
    if (!content.contains('status: pending_supported_web_execution') &&
        !content.contains('status: verified')) {
      _fail('Web candidate evidence has an unsupported status.');
    }
    stdout.writeln(
      'Web candidate evidence contract is ready; execution remains pending.',
    );
    return;
  }

  for (final required in [
    'status: verified',
    'working_tree_clean_at_execution: true',
    'supabase_connected: true',
    'server_ai_connected: true',
    'mock_persistence: false',
    'privacy_reviewed: true',
    for (final check in _requiredChecks) '  $check: passed',
  ]) {
    _expect(content, required);
  }
  final browser = _scalar(content, 'browser_family', indent: 2);
  if (!{'chrome', 'edge'}.contains(browser)) {
    _fail('Web evidence must use Chrome or Edge.');
  }
  final candidateSha = _scalar(content, 'candidate_sha');
  final head = _command(['git', 'rev-parse', 'HEAD']).trim();
  if (candidateSha != head) _fail('Web evidence is not bound to HEAD.');

  final artifactMatch = RegExp(
    r'artifact:\n  path: "([^"]+)"\n  bytes: (\d+)\n  sha256: "([a-f0-9]{64})"',
  ).firstMatch(content);
  if (artifactMatch == null)
    _fail('Web candidate artifact evidence is incomplete.');
  await _verifyFile(artifactMatch, 'artifacts/candidate/');

  final entries = RegExp(
    r'  - check: ([a-z0-9_]+)\n'
    r'    path: "([^"]+)"\n'
    r'    bytes: (\d+)\n'
    r'    sha256: "([a-f0-9]{64})"',
  ).allMatches(content).toList();
  if (entries.length != _requiredChecks.length) {
    _fail('Exactly ${_requiredChecks.length} Web evidence files are required.');
  }
  final checks = entries.map((entry) => entry.group(1)).toSet();
  if (!checks.containsAll(_requiredChecks))
    _fail('Web evidence checks are incomplete.');
  for (final entry in entries) {
    await _verifyFile(entry, 'artifacts/qst396/');
  }
  stdout.writeln('Supported Web candidate evidence passed for $head.');
}

const _requiredChecks = <String>{
  'launch',
  'login',
  'quest_mission_task_trail',
  'arc',
  'japanese_ime',
  'keyboard',
  'responsive',
};

Future<void> _verifyFile(RegExpMatch entry, String requiredRoot) async {
  final path = entry.group(entry.groupCount == 3 ? 1 : 2)!;
  final bytes = int.parse(entry.group(entry.groupCount == 3 ? 2 : 3)!);
  final expectedHash = entry.group(entry.groupCount == 3 ? 3 : 4)!;
  final file = File(path);
  if (!path.startsWith(requiredRoot) || !file.existsSync()) {
    _fail('Evidence path is invalid: $path');
  }
  if (file.lengthSync() != bytes) _fail('Evidence size changed: $path');
  final actualHash = await _sha256(path);
  if (actualHash != expectedHash) _fail('Evidence checksum changed: $path');
}

String? _scalar(String content, String field, {int indent = 0}) {
  final match = RegExp(
    '^${RegExp.escape(' ' * indent + field)}:\\s*"?([^"\\s]+)"?\\s*\$',
    multiLine: true,
  ).firstMatch(content);
  return match?.group(1);
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

void _expect(String content, String snippet) {
  if (!content.contains(snippet)) _fail('Missing Web evidence: $snippet');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
