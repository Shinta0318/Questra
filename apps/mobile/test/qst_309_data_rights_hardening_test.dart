import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/202608090004_data_rights_reauthentication_worker.sql',
  ).readAsStringSync();

  test('account deletion requires recent auth and a cancellation window', () {
    expect(migration, contains("interval '10 minutes'"));
    expect(migration, contains("interval '72 hours'"));
    expect(migration, contains('cancel_my_data_rights_request'));
    expect(
      migration,
      contains(
        'drop function if exists public.submit_data_rights_request(text, jsonb)',
      ),
    );
  });

  test(
    'worker claims requests with locking, retries and service role only',
    () {
      expect(migration, contains('for update skip locked'));
      expect(migration, contains("auth.role() <> 'service_role'"));
      expect(migration, contains('attempt_count < 5'));
      expect(migration, contains("now() + interval '1 hour'"));
    },
  );

  test('worker endpoint has a separate secret and soft deletion', () {
    final worker = File(
      '../../supabase/functions/process-data-rights-requests/index.ts',
    ).readAsStringSync();
    expect(worker, contains('DATA_RIGHTS_WORKER_SECRET'));
    expect(worker, contains('constantTimeEqual'));
    expect(worker, contains('deleteUser'));
    expect(worker, contains('true,'));
  });
}
