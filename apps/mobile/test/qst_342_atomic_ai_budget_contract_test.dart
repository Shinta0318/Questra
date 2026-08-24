import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;

  String read(String path) => File('${repo.path}/$path').readAsStringSync();

  test('AI budget migration enforces atomic non-null admission limits', () {
    final sql = read(
      'supabase/migrations/202608240002_atomic_ai_budget_ledger.sql',
    );

    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains('alter column monthly_hard_limit set not null'));
    expect(sql, contains('monthly_cost_hard_limit_micros'));
    expect(sql, contains('per_minute_hard_limit'));
    expect(sql, contains("auth.role() is distinct from 'service_role'"));
    expect(sql, contains('unique (user_id, operation, idempotency_key)'));
    expect(sql, contains('network_abuse_limit'));
    expect(sql, contains('create or replace view public.ai_usage_cost_daily'));
    expect(sql, contains('admission_p95_ms'));
    expect(sql, contains('public.ai_budget_alerts'));
  });

  test('provider reserves before Gemini and settles or releases once', () {
    final adapter = read(
      'supabase/functions/_shared/quest_planning/interactions_adapter.ts',
    );
    final reserve = adapter.indexOf('await reserveAiBudget');
    final provider = adapter.indexOf('await fetch(INTERACTIONS_URL');

    expect(reserve, greaterThanOrEqualTo(0));
    expect(provider, greaterThan(reserve));
    expect(adapter, contains('await settleAiBudget'));
    expect(adapter, contains('await releaseAiBudget'));
    expect(adapter, contains('budget_exhausted'));
  });

  test('cost ledger stores metadata and never raw prompts or IP addresses', () {
    final sql = read(
      'supabase/migrations/202608240002_atomic_ai_budget_ledger.sql',
    );
    final admission = read(
      'supabase/functions/_shared/quest_planning/ai_budget_admission.ts',
    );
    final edge = read('supabase/functions/quest-planning-v2/index.ts');

    expect(sql, isNot(contains('raw_prompt')));
    expect(sql, isNot(contains('raw_response')));
    expect(sql, contains('abuse_key_hash'));
    expect(edge, contains('crypto.subtle.digest("SHA-256"'));
    expect(admission, isNot(contains('x-forwarded-for')));
  });

  test('actual provider tokens are mandatory for settlement', () {
    final admission = read(
      'supabase/functions/_shared/quest_planning/ai_budget_admission.ts',
    );
    final adapter = read(
      'supabase/functions/_shared/quest_planning/interactions_adapter.ts',
    );

    expect(admission, contains('response.usage.inputTokens === undefined'));
    expect(admission, contains('response.usage.outputTokens === undefined'));
    expect(adapter, contains('usage_metadata'));
    expect(adapter, contains('prompt_token_count'));
  });

  test('Flutter keeps user work and explains budget failures', () {
    final service = read(
      'apps/mobile/lib/features/quest/arc_quest_guide_service.dart',
    );

    expect(service, contains("case 'budget_exhausted':"));
    expect(service, contains('入力は残っています'));
    expect(service, contains('Missionを手動で追加できます'));
  });
}
