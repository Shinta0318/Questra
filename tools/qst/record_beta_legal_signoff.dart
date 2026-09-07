import 'dart:io';

const version = '2026-08-18-beta.1';
const intakePath = 'docs/qst/LEGAL_SIGNOFF_INTAKE.yaml';
const signoffPath = 'docs/qst/BETA_LEGAL_SIGNOFF.yaml';
const reconciliationPath = 'docs/qst/LEGAL_VERSION_RECONCILIATION.yaml';

void main(List<String> arguments) {
  final options = _Options.parse(arguments);
  final head = _command(['git', 'rev-parse', 'HEAD']).trim();
  if (_command(['git', 'status', '--porcelain']).trim().isNotEmpty) {
    _fail('Legal sign-off must be recorded from a clean worktree.');
  }
  if (options.candidateSha != head) _fail('Candidate SHA does not match HEAD.');
  final candidate = _read('docs/qst/BETA_CANDIDATE.yaml');
  if (!candidate.contains('source_commit: "$head"')) {
    _fail('Beta candidate manifest does not match HEAD.');
  }
  final hosted = _read('docs/qst/HOSTED_EVIDENCE_RUN.yaml');
  if (!hosted.contains('status: verified') ||
      !hosted.contains('candidate_source_commit: "$head"')) {
    _fail('Current candidate hosted evidence must be verified first.');
  }
  for (final path in [
    'docs/legal/terms_of_service_draft.md',
    'docs/legal/privacy_policy_draft.md',
    'docs/legal/beta_privacy_notice_ja_draft.md',
  ]) {
    if (!_read(path).contains(version)) _fail('$path does not use $version.');
  }
  for (final value in [
    options.operatorLegalName,
    options.serviceAddress,
    options.releaseManager,
    options.engineeringOwner,
    options.productOwner,
    options.legalReviewer,
  ]) {
    _singleLine(value);
  }
  _contact(options.privacyContact, 'privacy-contact');
  _contact(options.supportContact, 'support-contact');
  if (!options.confirmations.values.every((value) => value)) {
    _fail(
      'Every legal, provider, retention, and data-rights confirmation is required.',
    );
  }

  final approvedAt = DateTime.now().toUtc().toIso8601String();
  final intake = StringBuffer()
    ..writeln('version: 1')
    ..writeln('qst: QST-398')
    ..writeln('status: approved')
    ..writeln('candidate_source_commit: "$head"')
    ..writeln('working_tree_clean_at_intake: true')
    ..writeln('document_version: "$version"')
    ..writeln('approved_at_utc: "$approvedAt"')
    ..writeln('operator_legal_name: "${_yaml(options.operatorLegalName)}"')
    ..writeln('service_address: "${_yaml(options.serviceAddress)}"')
    ..writeln('privacy_contact: "${_yaml(options.privacyContact)}"')
    ..writeln('support_contact: "${_yaml(options.supportContact)}"')
    ..writeln('signoff_records:');
  for (final entry in options.signoffs.entries) {
    intake
      ..writeln('  - role: ${entry.key}')
      ..writeln('    name: "${_yaml(entry.value)}"')
      ..writeln('    decision: approved')
      ..writeln('    approved_at_utc: "$approvedAt"');
  }
  intake
    ..writeln('guardrails:')
    ..writeln('  hosted_evidence_required: true')
    ..writeln('  signature_image_recorded: false')
    ..writeln('  credential_values_recorded: false')
    ..writeln('  private_account_identifier_recorded: false')
    ..writeln('  approval_inferred_from_code: false')
    ..writeln('  missing_contact_allows_distribution: false');
  final previous = <String, String>{
    for (final path in [intakePath, signoffPath, reconciliationPath])
      path: _read(path),
  };
  try {
    File(intakePath).writeAsStringSync(intake.toString());
    File(
      signoffPath,
    ).writeAsStringSync(_betaSignoff(options, head, approvedAt));
    File(
      reconciliationPath,
    ).writeAsStringSync(_reconciliation(head, approvedAt));
    _verify('tools/qst/verify_legal_signoff_intake.dart', '--require-approved');
    _verify(
      'tools/qst/verify_beta_privacy_copy_readiness.dart',
      '--require-signoff',
    );
    _verify('tools/qst/verify_legal_version_reconciliation.dart');
  } catch (error) {
    for (final entry in previous.entries) {
      File(entry.key).writeAsStringSync(entry.value);
    }
    _fail('Legal sign-off failed and previous manifests were restored: $error');
  }
  stdout.writeln(
    'Beta legal sign-off recorded for $head without signature images.',
  );
}

void _verify(String path, [String? argument]) {
  final result = Process.runSync('dart', [
    'run',
    path,
    if (argument != null) argument,
  ]);
  if (result.exitCode != 0) throw StateError(result.stderr.toString().trim());
}

String _betaSignoff(_Options options, String head, String approvedAt) =>
    '''version: 3
status: approved
candidate_source_commit: "$head"
working_tree_clean_at_signoff: true
document_version: "$version"
updated_at_utc: "$approvedAt"
implementation:
  eligibility_gate: implemented_hosted
  minimum_age_confirmation: 18
  region_code: JP
  terms_version: "$version"
  privacy_version: "$version"
  ai_disclosure_version: "$version"
  server_version_validation: verified
  append_only_acceptance_evidence: verified
operator:
  legal_name: "${_yaml(options.operatorLegalName)}"
  service_address: "${_yaml(options.serviceAddress)}"
privacy_contact: "${_yaml(options.privacyContact)}"
support_contact: "${_yaml(options.supportContact)}"
audience:
  target_region: Japan internal beta
  minimum_age: 18
  age_rule_legally_verified: true
supabase:
  project_ref: dhbmgwarnrtelrcrmmfk
  primary_region: ap-northeast-1
  region_verified: true
  dpa_verified: true
  subprocessors_verified: true
ai_provider:
  default: gemini
  compatibility: openai_explicit_only
  request_store: false
  paid_service_verified: true
  logging_disabled_verified: true
  provider_retention_verified: true
retention:
  crash_error_days: 30
  account_data_retention_verified: true
  supabase_backup_retention_verified: true
data_requests:
  request_procedure_verified: true
  account_deletion_available: true
  data_export_available: true
  correction_available: true
  consent_withdrawal_available: true
  local_implementation: implemented
  latest_migration: "202608250007_data_rights_fulfillment_sla.sql"
  hosted_owner_isolation_verified: true
  deletion_worker_verified: true
signoffs:
  legal_reviewer: approved
  product_owner: approved
  release_manager: approved
  engineering_owner: approved
signoff_records:
  - role: release_manager
    name: "${_yaml(options.releaseManager)}"
    approved_at_utc: "$approvedAt"
  - role: engineering_owner
    name: "${_yaml(options.engineeringOwner)}"
    approved_at_utc: "$approvedAt"
  - role: product_owner
    name: "${_yaml(options.productOwner)}"
    approved_at_utc: "$approvedAt"
  - role: legal_reviewer
    name: "${_yaml(options.legalReviewer)}"
    approved_at_utc: "$approvedAt"
guardrails:
  external_distribution_before_approval: false
  legal_gate_bypass_allowed: false
  unapproved_region_access_allowed: false
  credential_values_recorded: false
  signatures_recorded_in_repository: false
''';

String _reconciliation(String head, String approvedAt) =>
    '''version: 2
qst: QST-388
status: versions_aligned_approved
candidate_source_commit: "$head"
approved_at_utc: "$approvedAt"
region: JP
minimum_age: 18
active_version: "$version"
sources:
  app_policy: apps/mobile/lib/features/trust/legal_policy.dart
  database_policy: supabase/migrations/202608180001_versioned_legal_eligibility_gate.sql
  terms: docs/legal/terms_of_service_draft.md
  privacy_policy: docs/legal/privacy_policy_draft.md
  beta_privacy_notice: docs/legal/beta_privacy_notice_ja_draft.md
  signoff: docs/qst/BETA_LEGAL_SIGNOFF.yaml
  signoff_intake: docs/qst/LEGAL_SIGNOFF_INTAKE.yaml
approval:
  release_manager: approved
  engineering_owner: approved
  product_owner: approved
  legal_reviewer: approved
  operator_identity: approved
  privacy_contact: approved
guardrails:
  aligned_version_is_legal_approval: false
  draft_is_public_policy: false
  missing_contact_allows_distribution: false
  stale_acceptance_remains_current: false
''';

class _Options {
  const _Options(this.values, this.confirmations);

  final Map<String, String> values;
  final Map<String, bool> confirmations;

  String get candidateSha => values['candidate-sha']!;
  String get operatorLegalName => values['operator-legal-name']!;
  String get serviceAddress => values['service-address']!;
  String get privacyContact => values['privacy-contact']!;
  String get supportContact => values['support-contact']!;
  String get releaseManager => values['release-manager']!;
  String get engineeringOwner => values['engineering-owner']!;
  String get productOwner => values['product-owner']!;
  String get legalReviewer => values['legal-reviewer']!;

  Map<String, String> get signoffs => {
    'release_manager': releaseManager,
    'engineering_owner': engineeringOwner,
    'product_owner': productOwner,
    'legal_reviewer': legalReviewer,
  };

  factory _Options.parse(List<String> arguments) {
    final values = <String, String>{};
    for (final argument in arguments) {
      final separator = argument.indexOf('=');
      if (!argument.startsWith('--') || separator < 3) continue;
      values[argument.substring(2, separator)] = argument.substring(
        separator + 1,
      );
    }
    const requiredValues = [
      'candidate-sha',
      'operator-legal-name',
      'service-address',
      'privacy-contact',
      'support-contact',
      'release-manager',
      'engineering-owner',
      'product-owner',
      'legal-reviewer',
    ];
    for (final key in requiredValues) {
      if ((values[key] ?? '').trim().isEmpty) _fail('Missing required --$key.');
    }
    const confirmationKeys = [
      'age-rule-verified',
      'dpa-verified',
      'subprocessors-verified',
      'paid-service-verified',
      'logging-disabled-verified',
      'provider-retention-verified',
      'account-retention-verified',
      'backup-retention-verified',
      'data-request-procedure-verified',
      'hosted-data-rights-verified',
    ];
    return _Options(values, {
      for (final key in confirmationKeys) key: values[key] == 'true',
    });
  }
}

void _singleLine(String value) {
  if (value.contains(RegExp(r'[\r\n\u0000-\u001f]')) || value.length > 240) {
    _fail(
      'Sign-off values must be safe single lines of at most 240 characters.',
    );
  }
}

void _contact(String value, String field) {
  _singleLine(value);
  final email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  final uri = Uri.tryParse(value);
  final https = uri?.scheme == 'https' && (uri?.host.isNotEmpty ?? false);
  if (!email && !https) _fail('$field must be a public email or HTTPS URL.');
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing $path');
  return file.readAsStringSync();
}

String _command(List<String> command) {
  final result = Process.runSync(command.first, command.skip(1).toList());
  if (result.exitCode != 0) _fail(result.stderr.toString());
  return result.stdout.toString();
}

String _yaml(String value) => value.replaceAll('"', '\\"');

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
