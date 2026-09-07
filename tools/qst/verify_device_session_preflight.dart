import 'dart:io';

void main() {
  final failures = <String>[];
  final files = <String, List<String>>{
    'docs/qst/DEVICE_SESSION_PREFLIGHT.yaml': [
      'clean_worktree_required: true',
      'id: android_physical',
      'emulator_allowed: false',
      'japanese_ime',
      'talkback',
      'large_text_200',
      'id: supported_web',
      'mock_persistence_allowed: false',
      'credentials_in_evidence: prohibited',
      'stale_sha_evidence_allowed: false',
    ],
    'tools/qst/record_physical_accessibility_evidence.dart': [
      'Physical evidence must be recorded from a clean worktree.',
      'Candidate SHA does not match HEAD.',
      'Emulator output cannot be recorded as physical evidence.',
      'privacy-reviewed',
    ],
    'docs/qst/BETA_DEVICE_VALIDATION.yaml': [
      'class: android_phone',
      'class: web_sanity',
      'candidate_binding: github.sha',
      'mock_server_is_device_evidence: false',
    ],
  };
  for (final entry in files.entries) {
    final file = File(entry.key);
    if (!file.existsSync()) {
      failures.add('Missing ${entry.key}');
      continue;
    }
    final content = file.readAsStringSync();
    for (final snippet in entry.value) {
      if (!content.contains(snippet))
        failures.add('${entry.key} missing "$snippet"');
    }
  }
  if (failures.isNotEmpty) {
    stderr.writeln('Device session preflight failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    'Device session preflight passed; physical execution is still pending.',
  );
}
