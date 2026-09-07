import 'dart:io';

const outputPath = 'docs/qst/PHYSICAL_ACCESSIBILITY_EVIDENCE.yaml';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final head = _command(['git', 'rev-parse', 'HEAD']).trim();
  final dirty = _command(['git', 'status', '--porcelain']).trim().isNotEmpty;
  if (dirty) _fail('Physical evidence must be recorded from a clean worktree.');
  if (options.candidateSha != head) {
    _fail('Candidate SHA does not match HEAD.');
  }
  if (!options.privacyReviewed) {
    _fail('Evidence requires explicit privacy review confirmation.');
  }
  final device = _verifyPhysicalAndroid(options.adbCommand, options.deviceId);
  final candidate = File('docs/qst/BETA_CANDIDATE.yaml').readAsStringSync();
  if (!candidate.contains('source_commit: "$head"')) {
    _fail('Beta candidate manifest does not match HEAD.');
  }
  final evidence = <String, _EvidenceFile>{};
  for (final entry in options.evidence.entries) {
    final path = entry.value.replaceAll('\\', '/');
    if (!path.startsWith('artifacts/qst376/')) {
      _fail('${entry.key} evidence must be under artifacts/qst376/.');
    }
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      _fail('${entry.key} evidence file is missing or empty: $path');
    }
    final hash = await _sha256(path);
    if (hash == null) _fail('Unable to hash $path');
    evidence[entry.key] = _EvidenceFile(path, file.lengthSync(), hash);
  }
  final output = StringBuffer()
    ..writeln('version: 1')
    ..writeln('qst: QST-376')
    ..writeln('status: verified')
    ..writeln('candidate_sha: "${options.candidateSha}"')
    ..writeln('working_tree_clean_at_execution: true')
    ..writeln('executed_at_utc: "${DateTime.now().toUtc().toIso8601String()}"')
    ..writeln('tester_role: "${_yaml(options.testerRole)}"')
    ..writeln('device_class: android_physical')
    ..writeln('device_model: "${_yaml(device.model)}"')
    ..writeln('os_version: "${_yaml(device.osVersion)}"')
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
    ..writeln('  account_identifier_recorded: false')
    ..writeln('  private_journey_content_recorded: false')
    ..writeln('  credential_or_token_recorded: false')
    ..writeln('  emulator_is_physical_evidence: false')
    ..writeln('  automated_test_replaces_human_evidence: false');
  File(outputPath).writeAsStringSync(output.toString());
  stdout.writeln('Physical accessibility evidence recorded for $head.');
}

class _Options {
  const _Options({
    required this.candidateSha,
    required this.testerRole,
    required this.deviceId,
    required this.adbCommand,
    required this.privacyReviewed,
    required this.evidence,
  });

  static const requiredEvidence = [
    'physical_android',
    'talkback',
    'japanese_ime',
    'large_text_200',
    'compact_layout',
    'reduced_motion_and_haptics',
  ];

  final String candidateSha;
  final String testerRole;
  final String deviceId;
  final String adbCommand;
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
    final evidence = <String, String>{};
    for (final key in requiredEvidence) {
      final value = values[key];
      if (value == null || value.trim().isEmpty) {
        _fail('Missing required --$key=<evidence path>.');
      }
      evidence[key] = value;
    }
    for (final key in [
      'candidate-sha',
      'tester-role',
      'device-id',
    ]) {
      if ((values[key] ?? '').trim().isEmpty) _fail('Missing required --$key.');
    }
    return _Options(
      candidateSha: values['candidate-sha']!,
      testerRole: values['tester-role']!,
      deviceId: values['device-id']!,
      adbCommand: values['adb'] ?? 'adb',
      privacyReviewed: values['privacy-reviewed'] == 'true',
      evidence: evidence,
    );
  }
}

class _PhysicalDevice {
  const _PhysicalDevice(this.model, this.osVersion);

  final String model;
  final String osVersion;
}

_PhysicalDevice _verifyPhysicalAndroid(String adb, String deviceId) {
  final devices = _command([adb, 'devices', '-l']);
  final matching = devices
      .split(RegExp(r'\r?\n'))
      .where((line) => line.startsWith('$deviceId\tdevice'))
      .toList();
  if (matching.length != 1) {
    _fail('The selected Android device is not connected and authorized.');
  }
  final qemu = _command([
    adb,
    '-s',
    deviceId,
    'shell',
    'getprop',
    'ro.kernel.qemu',
  ]).trim();
  if (qemu == '1' || deviceId.toLowerCase().startsWith('emulator-')) {
    _fail('Emulator output cannot be recorded as physical evidence.');
  }
  final model = _command([
    adb,
    '-s',
    deviceId,
    'shell',
    'getprop',
    'ro.product.model',
  ]).trim();
  final osVersion = _command([
    adb,
    '-s',
    deviceId,
    'shell',
    'getprop',
    'ro.build.version.release',
  ]).trim();
  if (model.isEmpty || osVersion.isEmpty) {
    _fail('Unable to read the physical Android device metadata.');
  }
  return _PhysicalDevice(model, osVersion);
}

class _EvidenceFile {
  const _EvidenceFile(this.path, this.bytes, this.sha256);

  final String path;
  final int bytes;
  final String sha256;
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

String _yaml(String value) => value.replaceAll('"', '\\"');

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
