import 'dart:io';

void main() {
  const manifestPath = 'docs/qst/IP_DATA_RIGHTS_PROOF_PACK.yaml';
  const requiredFiles = <String>[
    manifestPath,
    'docs/product/ip_data_rights_proof_pack.md',
    'docs/qst/BETA_LEGAL_SIGNOFF.yaml',
    'docs/legal/privacy_policy_draft.md',
    'docs/legal/terms_of_service_draft.md',
    'apps/mobile/pubspec.yaml',
    'apps/mobile/pubspec.lock',
    'apps/mobile/assets/characters/arc/arc_normal.png',
    'apps/mobile/assets/characters/arc/arc_excited.png',
    'apps/mobile/assets/characters/arc/arc_support.png',
    'apps/mobile/assets/characters/arc/arc_serious.png',
    'apps/mobile/assets/characters/arc/arc_worried.png',
    'apps/mobile/assets/characters/arc/arc_lonely.png',
    'apps/mobile/assets/characters/arc/arc_celebrate.png',
  ];
  final missing = requiredFiles.where((path) => !File(path).existsSync()).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('Missing proof-pack evidence: ${missing.join(', ')}');
    exitCode = 1;
    return;
  }

  final manifest = File(manifestPath).readAsStringSync();
  const requiredGuardrails = <String>[
    'external_distribution_approved: false',
    'contains_personal_data: false',
    'unknown_asset_release_allowed: false',
    'user_content_assignment_assumed: false',
    'consent_scope_expansion_allowed: false',
    'legal_signoff_inferred_from_code: false',
  ];
  final absent = requiredGuardrails.where((rule) => !manifest.contains(rule)).toList();
  if (absent.isNotEmpty) {
    stderr.writeln('Fail-closed proof-pack guardrails are missing: ${absent.join(', ')}');
    exitCode = 1;
    return;
  }
  if (manifest.contains('permitted_public_claim: true')) {
    stderr.writeln('An unreviewed public claim was enabled.');
    exitCode = 1;
    return;
  }
  stdout.writeln('QST-356 IP/data-rights proof pack: PASS (legal sign-off remains pending).');
}
