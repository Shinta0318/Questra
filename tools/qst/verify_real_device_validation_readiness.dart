import 'dart:io';

const validationDocPath = 'docs/product/real_device_beta_validation.md';
const evidencePath = 'docs/qst/BETA_DEVICE_VALIDATION.yaml';

const requiredDeviceClasses = [
  'android_phone',
  'small_phone',
  'large_phone',
  'tablet',
  'web_sanity',
];

const requiredChecks = [
  'home',
  'quest_mission_task_trail',
  'arc',
  'owner_switch',
  'fallback',
  'keyboard',
  'large_text',
  'no_p0_failure',
];

void main(List<String> arguments) {
  final requireDevices = arguments.contains('--require-devices');
  final failures = <String>[];
  final doc = _read(validationDocPath, failures);
  final evidence = _read(evidencePath, failures);

  for (final snippet in [
    'Real Device Beta Validation',
    'Required Devices',
    'Device Classes',
    'Preflight',
    'Manual Pass',
    'Cross Device Pass',
    'Result Log Template',
    'Stop Conditions',
    'Evidence To Capture',
    'Quest -> Mission -> Task -> Trail',
    'Android phone',
    'Small phone',
    'Large phone',
    'Tablet',
    'Web sanity',
    'flutter analyze',
    'flutter test',
    'Arc Chat',
    'Arc Memory',
    'Navigator Rank',
    '--require-devices',
  ]) {
    _expect(doc, snippet, validationDocPath, failures);
  }
  for (final guardrail in [
    'mock_server_is_device_evidence: false',
    'automated_tests_replace_manual_evidence: false',
    'credential_values_recorded: false',
    'private_journey_content_recorded: false',
    'ios_required_when_available: true',
  ]) {
    _expect(evidence, guardrail, evidencePath, failures);
  }
  for (final deviceClass in requiredDeviceClasses) {
    _expect(evidence, '- class: $deviceClass', evidencePath, failures);
  }
  _rejectSensitiveEvidence(evidence, failures);

  if (requireDevices) {
    if (!RegExp(r'^status: verified$', multiLine: true).hasMatch(evidence)) {
      failures.add('Top-level device evidence status must be verified.');
    }
    for (final deviceClass in requiredDeviceClasses) {
      _verifyResult(evidence, deviceClass, failures);
    }
    final iosAvailability = _scalar(evidence, 'availability', 2);
    if (iosAvailability == 'available') {
      _verifyResult(evidence, 'ios', failures);
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Real-device validation readiness failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }

  stdout.writeln('Real-device validation readiness passed.');
  stdout.writeln(
    requireDevices
        ? 'Candidate-bound device evidence is verified.'
        : 'Device evidence contract is ready; physical execution is separate.',
  );
}

void _verifyResult(String evidence, String deviceClass, List<String> failures) {
  final match = RegExp(
    r'^  - class: ' +
        RegExp.escape(deviceClass) +
        r'\s*$([\s\S]*?)(?=^  - class: |^ios:|^guardrails:)',
    multiLine: true,
  ).firstMatch(evidence);
  if (match == null) {
    failures.add('Missing device result: $deviceClass.');
    return;
  }
  final block = match.group(1)!;
  for (final snippet in [
    'status: passed',
    'candidate_source_commit:',
    'device:',
    'platform:',
    'executed_at_utc:',
    'tester_role:',
    'evidence_paths:',
  ]) {
    if (!block.contains(snippet)) {
      failures.add('$deviceClass result is missing $snippet');
    }
  }
  final commit = _scalar(block, 'candidate_source_commit', 4);
  if (commit == null || !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
    failures.add('$deviceClass requires a full candidate commit.');
  }
  for (final field in [
    'device',
    'platform',
    'executed_at_utc',
    'tester_role',
  ]) {
    if (_scalar(block, field, 4) == null) {
      failures.add('$deviceClass requires $field.');
    }
  }
  for (final check in requiredChecks) {
    if (!block.contains('      $check: passed')) {
      failures.add('$deviceClass check must pass: $check.');
    }
  }
  if (!RegExp(r'^      - (?!null\s*$).+', multiLine: true).hasMatch(block)) {
    failures.add('$deviceClass requires at least one evidence path.');
  }
}

void _rejectSensitiveEvidence(String evidence, List<String> failures) {
  for (final pattern in [
    RegExp(r'eyJ[A-Za-z0-9_-]{20,}'),
    RegExp(r'password\s*[:=]\s*\S+', caseSensitive: false),
    RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
  ]) {
    if (pattern.hasMatch(evidence)) {
      failures.add(
        'Possible credential or account identifier found in evidence.',
      );
    }
  }
}

String? _scalar(String content, String field, int indent) {
  final prefix = ' ' * indent;
  final match = RegExp(
    '^${RegExp.escape(prefix + field)}:\\s*"?([^"\\s]+)"?\\s*\$',
    multiLine: true,
  ).firstMatch(content);
  final value = match?.group(1);
  return value == null || value == 'null' || value == 'pending' ? null : value;
}

String _read(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing required file: $path');
    return '';
  }
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

void _expect(
  String content,
  String snippet,
  String path,
  List<String> failures,
) {
  if (!content.contains(snippet)) failures.add('Missing "$snippet" in $path.');
}
