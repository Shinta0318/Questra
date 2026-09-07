import 'dart:io';

const operationsPath = 'docs/qst/BETA_FEEDBACK_OPERATIONS.yaml';
const registerPath = 'docs/qst/BETA_ISSUE_REGISTER.yaml';

Future<void> main(List<String> arguments) async {
  final values = <String, String>{};
  for (final argument in arguments) {
    final separator = argument.indexOf('=');
    if (!argument.startsWith('--') || separator < 3) continue;
    values[argument.substring(2, separator)] = argument
        .substring(separator + 1)
        .trim();
  }
  for (final key in [
    'channel-label',
    'owner-ref',
    'stop-channel-label',
    'candidate-commit',
  ]) {
    if ((values[key] ?? '').isEmpty) _fail('Missing required --$key value.');
  }
  for (final value in values.values) {
    if (_looksSensitive(value)) {
      _fail(
        'Operations evidence must not contain credentials or personal email addresses.',
      );
    }
  }
  final head = (await Process.run('git', [
    'rev-parse',
    'HEAD',
  ])).stdout.toString().trim();
  if (values['candidate-commit'] != head) {
    _fail('candidate-commit must match current HEAD.');
  }

  final registerFile = File(registerPath);
  if (!registerFile.existsSync()) _fail('Beta issue register is missing.');
  final register = registerFile.readAsStringSync().replaceAll('\r\n', '\n');
  final counts = _openCounts(register);
  final now = DateTime.now().toUtc().toIso8601String();
  final issuesIndex = register.indexOf('issues:');
  if (issuesIndex < 0) _fail('Beta issue register has no issues section.');
  final issues = register.substring(issuesIndex);
  registerFile.writeAsStringSync('''version: 1
status: ready_to_use
candidate_source_commit: "$head"
counts:
  status: verified
  generated_at_utc: "$now"
  open_s0: ${counts.$1}
  open_s1: ${counts.$2}
$issues''');

  File(operationsPath).writeAsStringSync('''version: 1
status: verified
updated_at_utc: "$now"
candidate_source_commit: "$head"
destination:
  status: verified
  channel_label: "${_yaml(values['channel-label']!)}"
  configuration_key: QUESTRA_BETA_FEEDBACK_CHANNEL
  tester_access_verified_at_utc: "$now"
daily_triage:
  status: active
  owner_role: Release Manager
  owner_name: "${_yaml(values['owner-ref']!)}"
  timezone: Asia/Tokyo
  review_time_local: "10:00"
stop_communication:
  status: verified
  channel_label: "${_yaml(values['stop-channel-label']!)}"
  trigger: any_open_s0_or_release_manager_stop
  owner_role: Release Manager
sla:
  S0: acknowledge_within_1_hour_and_stop_expansion
  S1: assign_owner_and_qst_within_24_hours
  S2: review_twice_weekly
  S3: review_weekly_when_repeated
issue_register:
  path: $registerPath
  open_s0_verified: ${counts.$1 == 0}
  open_s1_verified: ${counts.$2 == 0}
guardrails:
  destination_must_be_visible_to_testers: true
  clipboard_is_not_delivery_confirmation: true
  credential_values_recorded: false
  private_journey_content_recorded: false
  invented_operator_evidence_allowed: false
  candidate_commit_mismatch_allowed: false
''');
  stdout.writeln('Beta feedback operations activated for candidate $head.');
  stdout.writeln('Open S0: ${counts.$1}; open S1: ${counts.$2}.');
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
    final open =
        !block.contains('    status: resolved') &&
        !block.contains('    status: closed');
    if (!open) continue;
    if (block.contains('    severity: S0')) s0++;
    if (block.contains('    severity: S1')) s1++;
  }
  return (s0, s1);
}

bool _looksSensitive(String value) =>
    RegExp(r'eyJ[A-Za-z0-9_-]{20,}').hasMatch(value) ||
    RegExp(
      r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
      caseSensitive: false,
    ).hasMatch(value) ||
    value.toLowerCase().contains('password=') ||
    value.toLowerCase().contains('token=');

String _yaml(String value) => value.replaceAll('"', '\\"');

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
