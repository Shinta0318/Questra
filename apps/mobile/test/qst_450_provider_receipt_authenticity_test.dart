import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609150002_provider_receipt_authenticity_replay_guard.sql',
  ).readAsStringSync();
  final receiptFoundation = File(
    '${repo.path}/supabase/migrations/'
    '202609130002_ai_budget_settlement_reconciliation.sql',
  ).readAsStringSync();
  final admission = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/'
    'ai_budget_admission.ts',
  ).readAsStringSync();
  final envExample = File(
    '${repo.path}/supabase/functions/.env.example',
  ).readAsStringSync();
  final runbook = File(
    '${repo.path}/docs/product/provider_receipt_authenticity.md',
  ).readAsStringSync();

  test('server-issued request context binds reservation and receipt', () {
    expect(migration, contains('receipt_nonce_hash'));
    expect(migration, contains('allowed_model_names'));
    expect(migration, contains('model_route_digest'));
    expect(migration, contains('record_ai_provider_execution_receipt_v4'));
    expect(migration, contains("digest(p_receipt_nonce, 'sha256')"));
    expect(migration, contains('ai_provider_request_binding_required'));
    expect(admission, contains('AI_RECEIPT_NONCE_SECRET'));
    expect(admission, contains('p_receipt_nonce_hash: binding.nonceHash'));
  });

  test('binding is rollout-gated and current receipt path remains available', () {
    expect(envExample, contains('AI_RECEIPT_BINDING_ENABLED=false'));
    expect(admission, contains('receiptBindingEnabled()'));
    expect(admission, contains('reserve_ai_usage_budget_v3'));
    expect(admission, contains('reserve_ai_usage_budget_v2'));
    expect(admission, contains('record_ai_provider_execution_receipt_v4'));
    expect(admission, contains('record_ai_provider_execution_receipt_v3'));
    expect(runbook, contains('既定OFF'));
  });

  test('trace operation route and model mismatch open an operator case', () {
    for (final reason in <String>[
      'receipt_nonce_mismatch',
      'receipt_trace_mismatch',
      'receipt_operation_mismatch',
      'receipt_model_route_mismatch',
      'receipt_model_not_allowed',
    ]) {
      expect(migration, contains(reason));
    }
    expect(migration, contains('open_ai_receipt_binding_conflict'));
    expect(migration, contains("'execution_evidence_conflict'"));
    expect(migration, contains("'operator_review', true"));
  });

  test('provider interaction replay is rejected before receipt persistence', () {
    expect(
      receiptFoundation,
      contains('ai_provider_execution_receipts_interaction_idx'),
    );
    expect(migration, contains('provider_interaction_id = p_provider_interaction_id'));
    expect(migration, contains('reservation_id <> p_reservation_id'));
    expect(migration, contains('provider_interaction_replay'));
    expect(migration, contains('exception when unique_violation'));
  });

  test('raw nonce provider output and secrets are absent from ledger columns', () {
    final reservationStart = migration.indexOf(
      'alter table public.ai_budget_reservations',
    );
    final receiptStart = migration.indexOf(
      'alter table public.ai_provider_execution_receipts',
    );
    final functionsStart = migration.indexOf(
      'create or replace function public.reserve_ai_usage_budget_v3',
    );
    final columns = migration.substring(reservationStart, functionsStart);
    expect(columns, isNot(contains('receipt_nonce text')));
    for (final forbidden in <String>[
      'prompt',
      'response_body',
      'provider_output',
      'api_key',
      'secret',
    ]) {
      expect(columns, isNot(contains(forbidden)));
    }
    expect(receiptStart, greaterThan(reservationStart));
  });

  test('duplicate delivery remains idempotent and settlement stays atomic', () {
    expect(migration, contains('record_ai_provider_execution_receipt_v3'));
    expect(migration, contains("v_result ->> 'recorded'"));
    expect(migration, contains('new.receipt_nonce_hash is not null'));
    expect(admission, contains('reconcile_ai_usage_budget'));
    expect(runbook, contains('二重計上'));
    expect(runbook, contains('Hosted Supabase'));
  });
}
