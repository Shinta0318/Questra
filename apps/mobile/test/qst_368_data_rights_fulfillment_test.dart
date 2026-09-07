import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/202608250007_data_rights_fulfillment_sla.sql',
  ).readAsStringSync();
  final worker = File(
    '../../supabase/functions/process-data-rights-requests/index.ts',
  ).readAsStringSync();

  test(
    'Data Rights requests receive bounded SLA and service-role workflows',
    () {
      expect(
        migration,
        contains("when 'consent_withdrawal' then interval '1 day'"),
      );
      expect(
        migration,
        contains("when 'account_deletion' then interval '3 days'"),
      );
      expect(migration, contains("else interval '30 days'"));
      expect(migration, contains("auth.role() <> 'service_role'"));
      expect(migration, contains('claim_pending_correction_requests'));
      expect(
        migration,
        contains(
          'revoke insert, update, delete on public.data_rights_requests',
        ),
      );
    },
  );

  test('fulfillment receipts and worker responses exclude owner and content', () {
    final receipt = RegExp(
      r'create table if not exists public\.data_rights_fulfillment_receipts([\s\S]*?)\);',
    ).firstMatch(migration)!.group(1)!;
    expect(receipt, isNot(contains('owner_id')));
    expect(receipt, isNot(contains('content')));
    expect(worker, isNot(contains('results.push')));
    expect(worker, contains('classifyWorkerError'));
  });

  test('consent withdrawal removes derived business signals', () {
    expect(migration, contains('fulfill_pending_consent_withdrawals'));
    expect(migration, contains("status = 'withdrawn'"));
    expect(migration, contains('delete from public.business_quest_signals'));
  });
}
