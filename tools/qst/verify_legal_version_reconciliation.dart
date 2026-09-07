import 'dart:io';

const reconciliationPath = 'docs/qst/LEGAL_VERSION_RECONCILIATION.yaml';
const version = '2026-08-18-beta.1';

void main() {
  final failures = <String>[];
  final required = <String, List<String>>{
    reconciliationPath: [
      'active_version: "$version"',
      'aligned_version_is_legal_approval: false',
    ],
    'apps/mobile/lib/features/trust/legal_policy.dart': [
      "eligibilityVersion = '$version'",
      "termsVersion = '$version'",
      "privacyVersion = '$version'",
      "aiDisclosureVersion = '$version'",
      "regionCode = 'JP'",
      'minimumAge = 18',
    ],
    'supabase/migrations/202608180001_versioned_legal_eligibility_gate.sql': [
      "'2026-08-18-beta.1'",
      "'JP'",
      'accept_current_legal_policy',
      'server_policy_match',
    ],
    'docs/legal/terms_of_service_draft.md': ['`$version`'],
    'docs/legal/privacy_policy_draft.md': ['`$version`'],
    'docs/legal/beta_privacy_notice_ja_draft.md': ['`$version`'],
    'docs/qst/BETA_LEGAL_SIGNOFF.yaml': [
      'document_version: "$version"',
      'terms_version: "$version"',
      'privacy_version: "$version"',
      'ai_disclosure_version: "$version"',
      'legal_reviewer:',
      'product_owner:',
    ],
  };
  for (final entry in required.entries) {
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
  final reconciliation = File(reconciliationPath).existsSync()
      ? File(reconciliationPath).readAsStringSync()
      : '';
  final status = RegExp(
    r'^status: versions_aligned_(signoff_pending|approved)$',
    multiLine: true,
  ).firstMatch(reconciliation)?.group(1);
  if (status == null) {
    failures.add(
      '$reconciliationPath must be signoff_pending or approved after version alignment.',
    );
  }
  if (failures.isNotEmpty) {
    stderr.writeln('Legal version reconciliation failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    status == 'approved'
        ? 'Legal versions and candidate-bound approval align at $version.'
        : 'Legal versions align at $version; human signoff remains pending.',
  );
}
