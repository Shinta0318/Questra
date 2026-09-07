import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final runner = File(
    '../../tools/qst/run_hosted_evidence_gate.ps1',
  ).readAsStringSync();
  final rls = File('../../supabase/tests/rls_behavior.sql').readAsStringSync();

  test('hosted runner starts clean and keeps extended drills explicit', () {
    expect(
      runner,
      contains(
        'Hosted evidence must start from a clean candidate working tree',
      ),
    );
    expect(runner, contains('verify_hosted_evidence_runner_v2.dart'));
    expect(
      runner,
      contains('data_rights_fulfillment: passed_retention_review_pending'),
    );
    expect(runner, contains('runtime_observability: passed'));
  });

  test('RLS suite covers owner metadata and denies operator tables', () {
    expect(rls, contains('owner can read own Data Rights request'));
    expect(rls, contains('other cannot read owner Data Rights request'));
    expect(rls, contains('owner can read own runtime evidence'));
    expect(rls, contains('app user cannot read runtime alert queue'));
    expect(rls, contains('app user cannot bypass runtime evidence RPC'));
  });
}
