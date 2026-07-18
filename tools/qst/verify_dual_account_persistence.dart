import 'dart:io';

const runnerPath = 'tools/qst/run_dual_account_persistence.dart';
const evidencePath = 'docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml';

void main(List<String> arguments) {
  final requireCloud = arguments.contains('--require-cloud');
  final failures = <String>[];
  final runner = _read(runnerPath, failures);
  final evidence = _read(evidencePath, failures);

  for (final name in [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'QST_BETA_ACCOUNT_A_EMAIL',
    'QST_BETA_ACCOUNT_A_PASSWORD',
    'QST_BETA_ACCOUNT_B_EMAIL',
    'QST_BETA_ACCOUNT_B_PASSWORD',
  ]) {
    _expect(runner, name, runnerPath, failures);
  }
  for (final snippet in [
    "await _expectOne(accountA, 'user_profiles'",
    "await _expectOne(accountA, 'quests'",
    "await _expectOne(accountA, 'missions'",
    "await _expectOne(accountA, 'arc_memories'",
    "await _expectNone(accountB, 'quests'",
    "await _expectNone(accountB, 'missions'",
    "await _expectNone(accountB, 'arc_memories'",
    "await accountA.delete('arc_memories'",
    "await accountA.delete('quests'",
  ]) {
    _expect(runner, snippet, runnerPath, failures);
  }
  for (final guardrail in [
    'credential_values_recorded: false',
    'anon_key_recorded: false',
    'account_emails_recorded: false',
    'private_journey_content_recorded: false',
    'local_fallback_is_cloud_evidence: false',
  ]) {
    _expect(evidence, guardrail, evidencePath, failures);
  }
  _rejectSecrets(evidence, failures);

  if (requireCloud) {
    if (!RegExp(r'^status: verified$', multiLine: true).hasMatch(evidence)) {
      failures.add('Dual-account cloud evidence must be verified.');
    }
    for (final result in [
      'account_a_profile_after_relogin: passed',
      'account_a_quest_after_relogin: passed',
      'account_a_mission_after_relogin: passed',
      'account_a_arc_memory_after_relogin: passed',
      'account_b_private_quest_visibility: denied',
      'account_b_private_mission_visibility: denied',
      'account_b_private_arc_memory_visibility: denied',
      'test_records_cleaned: true',
    ]) {
      _expect(evidence, result, evidencePath, failures);
    }
    final commit = _scalar(evidence, 'candidate_source_commit');
    if (commit == null || !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
      failures.add('A full candidate source commit is required.');
    }
    final projectRef = _scalar(evidence, 'project_ref');
    if (projectRef == null || !RegExp(r'^[a-z0-9]{20}$').hasMatch(projectRef)) {
      failures.add('A hosted project ref is required.');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Dual-account persistence verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln('Dual-account persistence verification passed.');
  stdout.writeln(
    requireCloud
        ? 'Real account persistence and isolation evidence are verified.'
        : 'Secure dual-account acceptance contract is ready.',
  );
}

void _rejectSecrets(String evidence, List<String> failures) {
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

String? _scalar(String content, String field) {
  final match = RegExp(
    '^${RegExp.escape(field)}:\\s*"?([^"\\s]+)"?\\s*\$',
    multiLine: true,
  ).firstMatch(content);
  return match?.group(1);
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
