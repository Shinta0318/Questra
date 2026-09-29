import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609130007_grounding_query_cost_ledger.sql',
  ).readAsStringSync();
  final admission = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/'
    'ai_budget_admission.ts',
  ).readAsStringSync();
  final adapter = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/'
    'interactions_adapter.ts',
  ).readAsStringSync();
  final orchestrator = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/'
    'tool_interaction_orchestrator.ts',
  ).readAsStringSync();
  final runbook = File(
    '${repo.path}/docs/product/grounding_query_cost_ledger.md',
  ).readAsStringSync();

  test('pricing is versioned per unique non-empty provider query', () {
    expect(migration, contains("'unique_non_empty_query'"));
    expect(migration, contains("'gemini_google_search_query_20260913'"));
    expect(migration, contains('14000'));
    expect(
      migration,
      contains('https://ai.google.dev/gemini-api/docs/pricing'),
    );
    expect(migration, contains("'conservative_gross_rate'"));
  });

  test('grounding is reserved only for an explicit search tool request', () {
    expect(admission, contains('requestsGoogleSearch(request)'));
    expect(admission, contains('reserve_ai_grounding_budget'));
    expect(admission, contains('AI_GROUNDING_MAX_QUERIES_PER_REQUEST'));
    expect(admission, contains('grounding_budget_unavailable'));
  });

  test('provider evidence count is validated before settlement', () {
    expect(adapter, contains('billableQueryCount: queries.size'));
    expect(adapter, contains('item.type === "google_search_call"'));
    expect(admission, contains('verifiedGroundingQueryCount'));
    expect(admission, contains('record_ai_provider_execution_receipt_v'));
    expect(migration, contains('provider_execution_receipt_required'));
    expect(migration, contains('ai_grounding_query_count_exceeds_reservation'));
    expect(migration, contains('ai_grounding_provider_evidence_required'));
    expect(orchestrator, contains('groundingQueryCount(first) +'));
    expect(
      orchestrator,
      contains('uniqueNonEmptyStrings(first.queries, second.queries)'),
    );
  });

  test('token and grounding costs settle separately and atomically', () {
    expect(migration, contains('token_cost_micros'));
    expect(migration, contains('grounding_cost_micros'));
    expect(migration, contains('total_cost_micros'));
    expect(migration, contains('release_grounding_reservation_with_base'));
    expect(migration, contains("new.status in ('released', 'expired')"));
  });

  test('cost ledger excludes content and direct journey identifiers', () {
    final start = migration.indexOf(
      'create table if not exists public.ai_grounding_budget_reservations',
    );
    final end = migration.indexOf(
      'create table if not exists public.ai_grounding_monthly_counters',
    );
    final ledgerTable = migration.substring(start, end);
    for (final forbidden in <String>[
      'query_text',
      'source_uri',
      'user_id',
      'quest_id',
      'mission_id',
      'prompt',
      'response',
    ]) {
      expect(ledgerTable, isNot(contains(forbidden)));
    }
  });

  test(
    'missing price fails closed and runbook preserves evidence boundary',
    () {
      expect(migration, contains('ai_grounding_cost_rate_missing'));
      expect(migration, isNot(contains('estimated_grounding_query_count')));
      expect(runbook, contains('検索語やURLを保存しない'));
      expect(runbook, contains('provider metadata'));
      expect(runbook, contains('Hosted Supabase'));
    },
  );
}
