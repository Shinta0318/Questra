import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosted runner binds deployment RLS and dual-account evidence', () {
    final runner = File(
      '../../tools/qst/run_hosted_evidence_gate.ps1',
    ).readAsStringSync();
    expect(runner, contains('clean candidate working tree'));
    expect(runner, contains('bootstrap_supabase_beta.ps1'));
    expect(runner, contains('capture_cloud_rls_evidence.ps1'));
    expect(runner, contains('run_qst199_cloud_acceptance.ps1'));
    expect(runner, contains('--expected-sha='));
  });

  test('dual-account runner covers current data-rights boundaries', () {
    final runner = File(
      '../../tools/qst/run_dual_account_persistence.dart',
    ).readAsStringSync();
    expect(runner, contains('expectDataExportContains'));
    expect(runner, contains('expectDataExportExcludes'));
    expect(runner, contains('submitCorrectionRequest'));
    expect(runner, contains('expectPersonalSharingGrantAndWithdrawal'));
  });

  test('hosted verifier requires each evidence clean-worktree field', () {
    final verifier = File(
      '../../tools/qst/verify_hosted_evidence_bundle.dart',
    ).readAsStringSync();
    expect(verifier, contains('working_tree_clean_at_deploy: true'));
    expect(verifier, contains('working_tree_clean_at_execution: true'));
    expect(
      verifier,
      isNot(contains("evidence.contains('working_tree_clean_at_')")),
    );
  });
}
