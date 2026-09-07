import 'dart:io';

const evidencePath = 'docs/qst/ANDROID_CANDIDATE_SESSION.yaml';

Future<void> main(List<String> arguments) async {
  final requirePhysical = arguments.contains('--require-physical');
  final file = File(evidencePath);
  if (!file.existsSync()) _fail('Android candidate evidence is missing.');
  final content = file.readAsStringSync().replaceAll('\r\n', '\n');
  for (final required in [
    'emulator_is_physical_evidence: false',
    'mock_persistence_is_candidate_evidence: false',
    'automated_test_replaces_human_evidence: false',
    'credential_or_token_recorded: false',
    'account_identifier_recorded: false',
    'private_journey_content_recorded: false',
    'artifact_content_committed: false',
  ]) {
    _expect(content, required);
  }
  if (!requirePhysical) {
    if (!content.contains('status: pending_physical_android_execution') &&
        !content.contains('status: verified')) {
      _fail('Android candidate evidence has an unsupported status.');
    }
    stdout.writeln(
      'Android candidate evidence contract is ready; execution remains pending.',
    );
    return;
  }

  for (final required in [
    'status: verified',
    'working_tree_clean_at_execution: true',
    'device_class: android_physical',
    'supabase_connected: true',
    'server_ai_connected: true',
    'mock_persistence: false',
    'privacy_reviewed: true',
    for (final check in _requiredChecks) '  $check: passed',
  ]) {
    _expect(content, required);
  }
  final candidateSha = _scalar(content, 'candidate_sha');
  final head = _command(['git', 'rev-parse', 'HEAD']).trim();
  if (candidateSha != head) _fail('Android evidence is not bound to HEAD.');

  final artifactMatch = RegExp(
    r'artifact:\n  path: "([^"]+\.apk)"\n  bytes: (\d+)\n  sha256: "([a-f0-9]{64})"',
  ).firstMatch(content);
  if (artifactMatch == null) _fail('Android candidate artifact is incomplete.');
  await _verifyFile(artifactMatch, 'artifacts/candidate/');

  final entries = RegExp(
    r'  - check: ([a-z0-9_]+)\n'
    r'    path: "([^"]+)"\n'
    r'    bytes: (\d+)\n'
    r'    sha256: "([a-f0-9]{64})"',
  ).allMatches(content).toList();
  if (entries.length != _requiredChecks.length) {
    _fail(
      'Exactly ${_requiredChecks.length} Android evidence files are required.',
    );
  }
  if (!entries
      .map((entry) => entry.group(1))
      .toSet()
      .containsAll(_requiredChecks)) {
    _fail('Android evidence checks are incomplete.');
  }
  for (final entry in entries) {
    await _verifyFile(entry, 'artifacts/qst397/');
  }
  stdout.writeln('Physical Android candidate evidence passed for $head.');
}

const _requiredChecks = <String>{
  'install_launch',
  'login',
  'quest_mission_task_trail',
  'arc',
  'japanese_ime',
  'talkback',
  'large_text_200',
  'compact_layout',
  'reduced_motion_and_haptics',
};

Future<void> _verifyFile(RegExpMatch entry, String requiredRoot) async {
  final offset = entry.groupCount == 3 ? 0 : 1;
  final path = entry.group(1 + offset)!;
  final bytes = int.parse(entry.group(2 + offset)!);
  final expectedHash = entry.group(3 + offset)!;
  final file = File(path);
  if (!path.startsWith(requiredRoot) || !file.existsSync()) {
    _fail('Evidence path is invalid: $path');
  }
  if (file.lengthSync() != bytes) _fail('Evidence size changed: $path');
  if (await _sha256(path) != expectedHash)
    _fail('Evidence checksum changed: $path');
}

String? _scalar(String content, String field) => RegExp(
  '^${RegExp.escape(field)}:\\s*"?([^"\\s]+)"?\\s*\$',
  multiLine: true,
).firstMatch(content)?.group(1);

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
  if (!content.contains(snippet)) _fail('Missing Android evidence: $snippet');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
