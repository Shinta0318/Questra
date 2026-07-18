import 'dart:io';

const noticePath = 'docs/legal/beta_privacy_notice_ja_draft.md';
const privacyPath = 'docs/legal/privacy_policy_draft.md';
const termsPath = 'docs/legal/terms_of_service_draft.md';
const reviewPath = 'docs/product/beta_privacy_legal_copy_review.md';
const evidencePath = 'docs/qst/BETA_LEGAL_SIGNOFF.yaml';
const servicePath =
    'apps/mobile/lib/features/trust/trust_privacy_review_service.dart';
const providerPath = 'supabase/functions/_shared/ai_provider.ts';

void main(List<String> arguments) {
  final requireSignoff = arguments.contains('--require-signoff');
  final failures = <String>[];
  final notice = _read(noticePath, failures);
  final privacy = _read(privacyPath, failures);
  final terms = _read(termsPath, failures);
  final review = _read(reviewPath, failures);
  final evidence = _read(evidencePath, failures);
  final service = _read(servicePath, failures);
  final provider = _read(providerPath, failures);

  for (final snippet in [
    '保存するデータ',
    'Arcの生成時に処理するデータ',
    'Gemini API',
    'OpenAI互換経路',
    'store=false',
    '東京',
    '現在利用できない操作',
    '法務確認',
  ]) {
    _expect(notice, snippet, noticePath, failures);
  }
  for (final snippet in [
    'Gemini API',
    'OpenAI compatibility',
    'store=false',
    'Tokyo',
    'Contact',
  ]) {
    _expect(privacy, snippet, privacyPath, failures);
  }
  for (final snippet in ['Arc', '18', 'human legal review']) {
    _expect(terms, snippet, termsPath, failures);
  }
  for (final snippet in [
    'Implementation Audit',
    'Gemini Interactions API',
    'store=false',
    'Open Blockers',
    'human legal review',
    '--require-signoff',
  ]) {
    _expect(review, snippet, reviewPath, failures);
  }
  for (final snippet in [
    'Gemini API',
    'OpenAI互換経路',
    'request保存は無効',
    '東京リージョン',
  ]) {
    _expect(service, snippet, servicePath, failures);
  }
  _expect(provider, 'store: false', providerPath, failures);
  for (final snippet in [
    'operator:',
    'privacy_contact:',
    'target_region:',
    'supabase:',
    'ai_provider:',
    'retention:',
    'signoffs:',
    'credential_values_recorded: false',
  ]) {
    _expect(evidence, snippet, evidencePath, failures);
  }
  _rejectSecrets(evidence, failures);

  if (requireSignoff) {
    if (!RegExp(r'^status: approved$', multiLine: true).hasMatch(evidence)) {
      failures.add('Legal sign-off evidence must be approved.');
    }
    for (final field in [
      'legal_name',
      'service_address',
      'privacy_contact',
      'support_contact',
      'minimum_age',
    ]) {
      if (_scalar(evidence, field) == null) failures.add('$field is required.');
    }
    for (final result in [
      'region_verified: true',
      'age_rule_legally_verified: true',
      'dpa_verified: true',
      'subprocessors_verified: true',
      'paid_service_verified: true',
      'logging_disabled_verified: true',
      'provider_retention_verified: true',
      'account_data_retention_verified: true',
      'supabase_backup_retention_verified: true',
      'request_procedure_verified: true',
      'legal_reviewer: approved',
      'product_owner: approved',
    ]) {
      _expect(evidence, result, evidencePath, failures);
    }
    final version = _scalar(evidence, 'document_version');
    if (version == null) failures.add('Versioned legal copy is required.');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Beta privacy copy readiness verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln('Beta privacy copy readiness verification passed.');
  stdout.writeln(
    requireSignoff
        ? 'Versioned legal copy and human sign-offs are verified.'
        : 'Gemini-first privacy copy and legal evidence contract are ready.',
  );
}

String? _scalar(String content, String field) {
  final match = RegExp(
    '^\\s*${RegExp.escape(field)}:\\s*"?([^"\\s]+)"?\\s*\$',
    multiLine: true,
  ).firstMatch(content);
  final value = match?.group(1);
  return value == null || value == 'null' || value == 'pending' ? null : value;
}

void _rejectSecrets(String content, List<String> failures) {
  for (final pattern in [
    RegExp(r'eyJ[A-Za-z0-9_-]{20,}'),
    RegExp(r'AIza[0-9A-Za-z_-]{30,}'),
    RegExp(r'password\s*[:=]\s*\S+', caseSensitive: false),
  ]) {
    if (pattern.hasMatch(content))
      failures.add('Possible secret in legal evidence.');
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
  String content,
  String snippet,
  String path,
  List<String> failures,
) {
  if (!content.contains(snippet)) failures.add('Missing "$snippet" in $path.');
}
