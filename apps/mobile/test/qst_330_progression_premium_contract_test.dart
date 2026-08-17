import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.parent.parent;
  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test('Stardust award RPC is server-authoritative and idempotent', () {
    final migration = read(
      'supabase/migrations/202608170001_stardust_progression_authority.sql',
    );

    expect(migration, contains('security definer'));
    expect(migration, contains('auth.uid()'));
    expect(migration, contains('on conflict (user_id, event_type, source_id)'));
    expect(migration, contains('source_not_completed_or_owned'));
    expect(migration, contains('user_profiles_progression_update_guard'));
    expect(migration, contains('progression_columns_are_server_managed'));
    expect(migration, contains('revoke all on function public.award_stardust'));
    expect(migration, isNot(contains('p_amount')));
  });

  test('client sends an event and source id but never an award amount', () {
    final auth = read('apps/mobile/lib/features/auth/auth_controller.dart');
    final arc = read('apps/mobile/lib/features/arc/arc_screen.dart');

    expect(auth, contains("'award_stardust'"));
    expect(auth, contains("'p_event_type'"));
    expect(auth, contains("'p_source_id'"));
    expect(auth, isNot(contains("'p_amount'")));
    expect(arc, isNot(contains('addStardust')));
    expect(arc, isNot(contains('stardustServiceProvider')));
  });

  test('Premium foundation keeps policy and usage under server control', () {
    final migration = read(
      'supabase/migrations/202608170002_ai_entitlement_foundation.sql',
    );

    expect(migration, contains('user_entitlements'));
    expect(migration, contains('ai_usage_policies'));
    expect(migration, contains('ai_usage_counters'));
    expect(migration, contains('resolve_ai_entitlement'));
    expect(migration, contains('security definer'));
    expect(migration, isNot(contains('price')));
    expect(migration, isNot(contains('payment')));
  });
}
