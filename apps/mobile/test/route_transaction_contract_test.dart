import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/202607250004_route_transaction_hardening.sql',
  ).readAsStringSync();

  test('apply RPC locks ownership and expected route version', () {
    expect(migration, contains('apply_route_change_proposal'));
    expect(migration, contains('for update'));
    expect(migration, contains('pg_advisory_xact_lock'));
    expect(migration, contains('owner_id = actor_id'));
    expect(migration, contains('p_expected_route_version_id'));
    expect(migration, contains('Stale route version'));
  });

  test(
    'apply stores a server snapshot and never silently accepts unknown actions',
    () {
      expect(migration, contains('route_snapshot = snapshot'));
      expect(migration, contains('Unsupported route action'));
      expect(migration, contains('created_mission_ids = created_ids'));
      expect(migration, contains("status = 'active'"));
    },
  );

  test('rollback restores route fields and preserves rows as history', () {
    expect(migration, contains('rollback_route_change_proposal'));
    expect(migration, contains("route_state = 'removed'"));
    expect(migration, isNot(contains('delete from public.missions')));
    expect(migration, isNot(contains('delete from public.trails')));
    expect(migration, contains("'status', 'rolledBack'"));
  });

  test('both RPCs are unavailable to public and granted to authenticated', () {
    expect(
      migration,
      contains(
        'revoke all on function public.apply_route_change_proposal(uuid, uuid[], uuid) from public',
      ),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.rollback_route_change_proposal(uuid) to authenticated',
      ),
    );
  });
}
