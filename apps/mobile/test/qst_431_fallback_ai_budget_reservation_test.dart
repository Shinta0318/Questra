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
    final recoveryMigration = read(
      'supabase/migrations/202609120002_ai_budget_idempotent_recovery.sql',
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
    expect(recoveryMigration, contains('idempotency_resumed'));
    expect(recoveryMigration, contains('pg_advisory_xact_lock'));
    expect(
      recoveryMigration,
      contains('reserved_cost_micros >= v_required_cost'),
    );
    expect(recoveryMigration, contains("v_existing.status = 'reserved'"));
    expect(recoveryMigration, contains('for update'));
    expect(migration, contains("auth.role() is distinct from 'service_role'"));
    expect(migration, contains('to service_role'));
    expect(admission, contains('reserve_ai_usage_budget_v2'));
    expect(admission, contains('p_model_names: modelNames'));
    expect(admission, contains('AI_BUDGET_RPC_TIMEOUT_MS'));
    expect(admission, contains('signal: controller.signal'));
    expect(admission, contains('clearTimeout(timeout)'));
    expect(admission, contains('attempt <= 2'));
    expect(admission, contains('response.status !== 429'));
    expect(adapter, contains('primaryModel.name'));
    expect(adapter, contains('fallbackModel.name'));
    expect(adapter, contains('if (!text)'));
    expect(adapter, contains('"Provider output was empty"'));
    expect(
      adapter.indexOf('if (!text)'),
      lessThan(adapter.indexOf('let output: unknown = text')),
    );
    expect(adapter, contains('usage.total_input_tokens'));
    expect(adapter, contains('usage.total_output_tokens'));
    expect(adapter, contains('usage.total_thought_tokens'));
    expect(
      adapter,
      contains('generatedOutputTokens + thoughtTokens'),
    );
    expect(adapter, contains('Number.isSafeInteger(value) && value >= 0'));
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
