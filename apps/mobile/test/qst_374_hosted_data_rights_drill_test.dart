import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/202608250007_data_rights_fulfillment_sla.sql',
  ).readAsStringSync();
  final drill = File(
    '../../tools/qst/run_data_rights_hosted_drill.ps1',
  ).readAsStringSync();

  test('hosted drill uses exact fixture-scoped service role operations', () {
    expect(migration, contains('claim_data_correction_request'));
    expect(migration, contains('fulfill_consent_withdrawal_request'));
    expect(migration, contains('claim_account_deletion_request'));
    expect(drill, contains("p_request_id = \$correction.id"));
    expect(drill, contains("p_request_id = \$withdrawal.id"));
    expect(drill, contains("p_request_id = \$deletionTwo.id"));
  });

  test('drill evidence is sanitized and cleanup failure blocks admission', () {
    expect(drill, contains('account_identifier_recorded_in_evidence: false'));
    expect(drill, contains('request_content_recorded_in_evidence: false'));
    expect(drill, contains('credential_or_worker_secret_recorded: false'));
    expect(drill, contains('cleanup failed; evidence is not admissible'));
    expect(
      drill.indexOf('if (\$script:cleanupFailed)'),
      lessThan(drill.indexOf("Set-Content -LiteralPath 'docs/qst/")),
    );
    expect(drill, contains('provider_retention_review: pending'));
  });
}
