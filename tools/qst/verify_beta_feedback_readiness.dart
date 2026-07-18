import 'dart:io';

const feedbackPlanPath = 'docs/qst/BETA_FEEDBACK.yaml';
const operationsDocPath = 'docs/product/beta_feedback_operations.md';
const operationsEvidencePath = 'docs/qst/BETA_FEEDBACK_OPERATIONS.yaml';
const issueRegisterPath = 'docs/qst/BETA_ISSUE_REGISTER.yaml';
const servicePath =
    'apps/mobile/lib/features/feedback/beta_feedback_service.dart';

void main(List<String> arguments) {
  final requireOperations = arguments.contains('--require-operations');
  final failures = <String>[];
  final plan = _read(feedbackPlanPath, failures);
  final doc = _read(operationsDocPath, failures);
  final operations = _read(operationsEvidencePath, failures);
  final register = _read(issueRegisterPath, failures);
  final service = _read(servicePath, failures);

  for (final snippet in [
    'intake_channels:',
    'required_fields:',
    'severity:',
    'triage_rules:',
    'qst_conversion:',
    'S0:',
    'S1:',
    'S2:',
    'S3:',
    'next_id_policy:',
  ]) {
    _expect(plan, snippet, feedbackPlanPath, failures);
  }
  for (final snippet in [
    'Beta Feedback Operations',
    'Intake',
    'Triage Rhythm',
    'Conversion To QST',
    'Beta Stop Conditions',
    'Launch Readiness Signal',
    'QUESTRA_BETA_FEEDBACK_CHANNEL',
    '--require-operations',
  ]) {
    _expect(doc, snippet, operationsDocPath, failures);
  }
  for (final snippet in [
    'QUESTRA_BETA_FEEDBACK_CHANNEL',
    'Beta窓口は準備中です',
    'betaFeedbackDestinationProvider',
  ]) {
    _expect(service, snippet, servicePath, failures);
  }
  for (final snippet in [
    'destination:',
    'daily_triage:',
    'sla:',
    'S0:',
    'S1:',
    'issue_register:',
    'credential_values_recorded: false',
    'private_journey_content_recorded: false',
  ]) {
    _expect(operations, snippet, operationsEvidencePath, failures);
  }
  for (final snippet in [
    'counts:',
    'open_s0:',
    'open_s1:',
    'issues:',
  ]) {
    _expect(register, snippet, issueRegisterPath, failures);
  }
  _rejectSecrets(operations, failures);
  _rejectSecrets(register, failures);

  if (requireOperations) {
    if (!RegExp(r'^status: verified$', multiLine: true).hasMatch(operations)) {
      failures.add('Feedback operations evidence must be verified.');
    }
    _expect(operations, 'destination:\n  status: verified',
        operationsEvidencePath, failures);
    _expect(operations, 'daily_triage:\n  status: active',
        operationsEvidencePath, failures);
    final channel = _scalar(operations, 'channel_label', 2);
    final owner = _scalar(operations, 'owner_name', 2);
    if (channel == null)
      failures.add('A tester-visible channel label is required.');
    if (owner == null) failures.add('A named daily triage owner is required.');
    _expect(
        register, 'counts:\n  status: verified', issueRegisterPath, failures);
    if (_scalar(register, 'generated_at_utc', 2) == null) {
      failures.add('Issue counts require a generated_at_utc timestamp.');
    }
    final openS0 = _integer(register, 'open_s0', 2, failures);
    final openS1 = _integer(register, 'open_s1', 2, failures);
    final actual = _openCounts(register);
    if (openS0 != actual.$1 || openS1 != actual.$2) {
      failures.add(
        'Declared open S0/S1 counts do not match the issue register.',
      );
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Beta feedback readiness verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln('Beta feedback readiness verification passed.');
  stdout.writeln(
    requireOperations
        ? 'Destination, owner, SLA, and issue counts are verified.'
        : 'Feedback implementation and operations contract are ready.',
  );
}

(int, int) _openCounts(String register) {
  var s0 = 0;
  var s1 = 0;
  final issuesSection = register.split('issues:').last;
  for (final match in RegExp(
    r'^  - id: .*?$([\s\S]*?)(?=^  - id: |\z)',
    multiLine: true,
  ).allMatches(issuesSection)) {
    final block = match.group(1)!;
    final isOpen = !block.contains('    status: resolved') &&
        !block.contains('    status: closed');
    if (!isOpen) continue;
    if (block.contains('    severity: S0')) s0++;
    if (block.contains('    severity: S1')) s1++;
  }
  return (s0, s1);
}

int _integer(String content, String field, int indent, List<String> failures) {
  final value = _scalar(content, field, indent);
  final parsed = int.tryParse(value ?? '');
  if (parsed == null) failures.add('Invalid integer field: $field.');
  return parsed ?? -1;
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

void _rejectSecrets(String content, List<String> failures) {
  for (final pattern in [
    RegExp(r'eyJ[A-Za-z0-9_-]{20,}'),
    RegExp(r'password\s*[:=]\s*\S+', caseSensitive: false),
    RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
  ]) {
    if (pattern.hasMatch(content)) {
      failures.add(
          'Possible credential or personal address in operations evidence.');
    }
  }
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
    String content, String snippet, String path, List<String> failures) {
  if (!content.contains(snippet)) failures.add('Missing "$snippet" in $path.');
}
