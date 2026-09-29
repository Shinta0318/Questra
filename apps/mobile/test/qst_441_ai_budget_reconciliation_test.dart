import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609130002_ai_budget_settlement_reconciliation.sql',
  ).readAsStringSync();
  final admission = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/'
    'ai_budget_admission.ts',
  ).readAsStringSync();
  final contracts = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/contracts.ts',
  ).readAsStringSync();
  final adapter = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/'
    'interactions_adapter.ts',
  ).readAsStringSync();

  test('provider receipt is recorded before settlement and can reconcile', () {
    final receipt = admission.indexOf('record_ai_provider_execution_receipt');
    final settlement = admission.indexOf('settle_ai_usage_budget');
    final reconciliation = admission.indexOf('reconcile_ai_usage_budget');
    expect(receipt, greaterThanOrEqualTo(0));
    expect(settlement, greaterThan(receipt));
    expect(reconciliation, greaterThan(settlement));
    expect(admission, contains('receiptOutcome.recorded !== true'));
    expect(admission, contains('outcome.reconciled === true'));
  });

  test('provider interaction identity is retained without output content', () {
    expect(contracts, contains('providerInteractionId?: string'));
    expect(adapter, contains('providerInteractionId: stringValue(data.id)'));
    expect(migration, contains('provider_interaction_id text'));
    expect(
      migration,
      contains('ai_provider_execution_receipts_interaction_idx'),
    );
    expect(migration, isNot(contains('response_body')));
    expect(migration, isNot(contains('provider_output')));
    expect(migration, isNot(contains('prompt_content')));
  });

  test('reconciliation keeps uncertain execution out of billing', () {
    expect(migration, contains("'provider_execution_receipt_missing'"));
    expect(migration, contains("'execution_unknown'"));
    expect(migration, contains("'operator_review', true"));
    expect(migration, contains("set status = 'expired'"));
    expect(
      migration,
      contains('reserved_count = greatest(reserved_count - 1, 0)'),
    );
    expect(
      migration,
      contains('reserved_cost_micros - v_reservation.reserved_cost_micros'),
    );
  });

  test('matching settlement is idempotent and conflicts fail closed', () {
    expect(migration, contains("v_reservation.status = 'settled'"));
    expect(migration, contains('matching_settlement_already_committed'));
    expect(migration, contains('settled_usage_does_not_match_receipt'));
    expect(migration, contains('provider_execution_receipt_conflict'));
    expect(migration, contains("v_reservation.status <> 'reserved'"));
    expect(migration, contains("set status = 'resolved'"));
    expect(migration, contains('reservation settled from provider receipt'));
  });

  test('reconciliation authority remains service-role only', () {
    expect(migration, contains("auth.role() is distinct from 'service_role'"));
    expect(
      migration,
      contains('revoke all on function public.reconcile_ai_usage_budget(uuid)'),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.reconcile_ai_usage_budget(uuid)',
      ),
    );
    expect(migration, contains('to service_role;'));
    expect(migration, contains('enable row level security'));
  });
}
