import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;

  String read(String path) =>
      File('${repo.path}/$path').readAsStringSync().replaceAll('\r\n', '\n');

  test('fallback candidates reserve against the highest active model cost', () {
    final migration = read(
      'supabase/migrations/202609120001_fallback_ai_budget_reservation.sql',
    );
    final admission = read(
      'supabase/functions/_shared/quest_planning/ai_budget_admission.ts',
    );
    final adapter = read(
      'supabase/functions/_shared/quest_planning/interactions_adapter.ts',
    );

    expect(migration, contains('reserve_ai_usage_budget_v2'));
    expect(migration, contains('p_model_names text[]'));
    expect(migration, contains('ai_model_cost_rate_missing'));
    expect(migration, contains('order by public.ai_token_cost_micros('));
    expect(migration, contains("auth.role() is distinct from 'service_role'"));
    expect(migration, contains('to service_role'));
    expect(admission, contains('reserve_ai_usage_budget_v2'));
    expect(admission, contains('p_model_names: modelNames'));
    expect(adapter, contains('primaryModel.name'));
    expect(adapter, contains('fallbackModel.name'));
    expect(
      adapter.indexOf('await reserveAiBudget'),
      lessThan(adapter.indexOf('await fetch(INTERACTIONS_URL')),
    );
  });

  test('unknown or unpriced fallback candidates fail closed', () {
    final migration = read(
      'supabase/migrations/202609120001_fallback_ai_budget_reservation.sql',
    );
    expect(migration, contains('v_priced_count <> v_requested_count'));
    expect(migration, contains('invalid_ai_model_candidates'));
    expect(migration, contains('invalid_ai_model_candidate'));
    expect(migration, isNot(contains('coalesce(v_model_name')));
  });
}
