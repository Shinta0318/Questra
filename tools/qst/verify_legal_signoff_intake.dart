import 'dart:io';

const intakePath = 'docs/qst/LEGAL_SIGNOFF_INTAKE.yaml';
const signoffPath = 'docs/qst/BETA_LEGAL_SIGNOFF.yaml';
const reconciliationPath = 'docs/qst/LEGAL_VERSION_RECONCILIATION.yaml';
const recorderPath = 'tools/qst/record_beta_legal_signoff.dart';

void main(List<String> arguments) {
  final failures = <String>[];
  final intake = _read(intakePath, failures);
  final signoff = _read(signoffPath, failures);
  final reconciliation = _read(reconciliationPath, failures);
  final recorder = _read(recorderPath, failures);
  for (final snippet in [
    'hosted_evidence_required: true',
    'signature_image_recorded: false',
    'credential_values_recorded: false',
    'approval_inferred_from_code: false',
    'missing_contact_allows_distribution: false',
    for (final role in _roles) '  - role: $role',
  ]) {
    _expect(intake, snippet, intakePath, failures);
  }
  for (final snippet in [
    'Legal sign-off must be recorded from a clean worktree.',
    'Current candidate hosted evidence must be verified first.',
    'Every legal, provider, retention, and data-rights confirmation is required.',
    'BETA_LEGAL_SIGNOFF.yaml',
    'LEGAL_VERSION_RECONCILIATION.yaml',
    'signatures_recorded_in_repository: false',
    'previous manifests were restored',
    'verify_beta_privacy_copy_readiness.dart',
  ]) {
    _expect(recorder, snippet, recorderPath, failures);
  }
  for (final snippet in [
    'document_version: "2026-08-18-beta.1"',
    'terms_version: "2026-08-18-beta.1"',
    'privacy_version: "2026-08-18-beta.1"',
    'ai_disclosure_version: "2026-08-18-beta.1"',
  ]) {
    _expect(signoff, snippet, signoffPath, failures);
  }

  if (arguments.contains('--require-approved')) {
    final head = _command(['git', 'rev-parse', 'HEAD']).trim();
    for (final pair in [
      (intake, 'status: approved', 'candidate_source_commit: "$head"'),
      (signoff, 'status: approved', 'candidate_source_commit: "$head"'),
      (
        reconciliation,
        'status: versions_aligned_approved',
        'candidate_source_commit: "$head"',
      ),
    ]) {
      _expect(pair.$1, pair.$2, 'approved legal evidence', failures);
      _expect(pair.$1, pair.$3, 'approved legal evidence', failures);
    }
    _expect(intake, 'working_tree_clean_at_intake: true', intakePath, failures);
    for (final role in _roles) {
      final record = RegExp(
        '  - role: $role\\n'
        '    name: "[^"]+"\\n'
        '    decision: approved\\n'
        '    approved_at_utc: "[^"]+"',
      );
      if (!record.hasMatch(intake))
        failures.add('Missing approved record: $role');
    }
    for (final field in [
      'operator_legal_name',
      'service_address',
      'privacy_contact',
      'support_contact',
      'approved_at_utc',
    ]) {
      if (_scalar(intake, field) == null)
        failures.add('Missing intake field: $field');
    }
  }
  _rejectSecrets(intake + signoff, failures);
  if (failures.isNotEmpty) {
    stderr.writeln('Legal sign-off intake verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    arguments.contains('--require-approved')
        ? 'Legal sign-off intake is approved and candidate-bound.'
        : 'Legal sign-off intake contract is ready; human approval remains pending.',
  );
}

const _roles = [
  'release_manager',
  'engineering_owner',
  'product_owner',
  'legal_reviewer',
];

String? _scalar(String content, String field) {
  final value = RegExp(
    '^${RegExp.escape(field)}:\\s*"?([^"\\n]+)"?\\s*\$',
    multiLine: true,
  ).firstMatch(content)?.group(1)?.trim();
  return value == null || value == 'null' || value == 'pending' ? null : value;
}

void _rejectSecrets(String content, List<String> failures) {
  for (final pattern in [
    RegExp(r'eyJ[A-Za-z0-9_-]{20,}'),
    RegExp(r'AIza[0-9A-Za-z_-]{30,}'),
    RegExp(r'password\s*[:=]\s*\S+', caseSensitive: false),
  ]) {
    if (pattern.hasMatch(content))
      failures.add('Possible secret in legal intake.');
  }
}

String _read(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing $path');
    return '';
  }
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

String _command(List<String> command) {
  final result = Process.runSync(command.first, command.skip(1).toList());
  if (result.exitCode != 0) _fail(result.stderr.toString());
  return result.stdout.toString();
}

void _expect(
  String content,
  String snippet,
  String path,
  List<String> failures,
) {
  if (!content.contains(snippet)) failures.add('$path missing: $snippet');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
