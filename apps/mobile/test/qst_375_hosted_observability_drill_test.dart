import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/202608250009_runtime_observability_exact_operator_drill.sql',
  ).readAsStringSync();
  final drill = File(
    '../../tools/qst/run_observability_hosted_drill.ps1',
  ).readAsStringSync();
  final rls = File('../../supabase/tests/rls_behavior.sql').readAsStringSync();

  test('hosted drill scopes alert claim and retention purge to fixtures', () {
    expect(migration, contains('claim_runtime_evidence_alert'));
    expect(migration, contains('purge_runtime_evidence_event'));
    expect(drill, contains('p_event_row_id = \$s0RowId'));
    expect(drill, contains('p_event_row_id = \$s1RowId'));
    expect(drill, contains('p_event_row_id = \$retentionRowId'));
    expect(rls, contains('app user cannot claim runtime evidence alert'));
    expect(rls, contains('app user cannot purge runtime evidence event'));
  });

  test('evidence is sanitized and emitted only after account cleanup', () {
    expect(drill, contains('raw_user_content_recorded: false'));
    expect(drill, contains('credential_or_token_recorded: false'));
    expect(drill, contains('cleanup failed; evidence is not admissible'));
    expect(
      drill.indexOf('if (\$script:cleanupFailed)'),
      lessThan(drill.indexOf("Set-Content -LiteralPath 'docs/qst/")),
    );
  });

  test('rate limit rejection is followed by a successful safe write', () {
    expect(drill, contains('Runtime evidence rate limit was not enforced.'));
    expect(drill, contains('qst375-recovery-\$runId'));
    expect(drill, contains('sink_failure_journey_continuity: passed'));
  });
}
