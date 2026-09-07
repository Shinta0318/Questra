import 'dart:io';

const evidencePath = 'docs/qst/PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml';

Future<void> main(List<String> arguments) async {
  final requirePhysical = arguments.contains('--require-physical');
  final file = File(evidencePath);
  if (!file.existsSync()) _fail('Physical accessibility evidence is missing.');
  final content = file.readAsStringSync().replaceAll('\r\n', '\n');
  for (final required in const [
    'emulator_is_physical_evidence: false',
    'automated_test_replaces_human_evidence: false',
    'account_identifier_recorded: false',
    'private_journey_content_recorded: false',
    'credential_or_token_recorded: false',
  ]) {
    _expect(content, required);
  }
  if (!requirePhysical) {
    if (!content.contains('status: pending_physical_execution') &&
        !content.contains('status: verified')) {
      _fail('Physical accessibility evidence has an unsupported status.');
    }
    stdout.writeln(
      'Physical accessibility evidence contract is ready; execution remains pending.',
    );
    return;
  }

  for (final required in const [
    'status: verified',
    'working_tree_clean_at_execution: true',
    'device_class: android_physical',
    'physical_android: passed',
    'talkback: passed',
    'japanese_ime: passed',
    'large_text_200: passed',
    'compact_layout: passed',
    'reduced_motion_and_haptics: passed',
    'privacy_reviewed: true',
  ]) {
    _expect(content, required);
  }
  final candidateSha = RegExp(
    r'^candidate_sha: "([a-f0-9]{40})"$',
    multiLine: true,
  ).firstMatch(content)?.group(1);
  final head = _command(['git', 'rev-parse', 'HEAD']).trim();
  if (candidateSha != head) _fail('Physical evidence is not bound to HEAD.');

  final entries = RegExp(
    r'  - check: ([a-z0-9_]+)\n'
    r'    path: "([^"]+)"\n'
    r'    bytes: (\d+)\n'
    r'    sha256: "([a-f0-9]{64})"',
  ).allMatches(content).toList();
  if (entries.length != 6)
    _fail('Exactly six physical evidence files are required.');
  final checks = entries.map((entry) => entry.group(1)).toSet();
  for (final check in const [
    'physical_android',
    'talkback',
    'japanese_ime',
    'large_text_200',
    'compact_layout',
    'reduced_motion_and_haptics',
  ]) {
    if (!checks.contains(check)) _fail('Missing physical evidence for $check.');
  }
  for (final entry in entries) {
    final path = entry.group(2)!;
    final evidence = File(path);
    if (!path.startsWith('artifacts/qst376/') || !evidence.existsSync()) {
      _fail('Physical evidence path is invalid: $path');
    }
    if (evidence.lengthSync() != int.parse(entry.group(3)!)) {
      _fail('Physical evidence size changed: $path');
    }
    if (await _sha256(path) != entry.group(4)) {
      _fail('Physical evidence hash changed: $path');
    }
  }
  stdout.writeln('Physical accessibility evidence passed for $head.');
}

void _expect(String content, String snippet) {
  if (!content.contains(snippet)) _fail('Missing physical evidence: $snippet');
}

String _command(List<String> command) {
  final result = Process.runSync(command.first, command.skip(1).toList());
  if (result.exitCode != 0) _fail(result.stderr as String);
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

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
