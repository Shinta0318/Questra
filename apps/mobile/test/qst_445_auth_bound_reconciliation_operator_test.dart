import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609130005_auth_bound_reconciliation_operator_identity.sql',
  ).readAsStringSync();
  final runbook = File(
    '${repo.path}/docs/product/ai_budget_operator_identity.md',
  ).readAsStringSync();

  String functionBody(String name, String nextName) {
    final start = migration.indexOf('create or replace function public.$name');
    final end = migration.indexOf(
      'create or replace function public.$nextName',
      start + 1,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    return migration.substring(start, end);
  }

  test('enabled human operators are uniquely bound to Supabase Auth', () {
    expect(migration, contains('auth_user_id uuid references auth.users(id)'));
    expect(migration, contains('on delete set null'));
    expect(migration, contains('ai_budget_reconciliation_auth_user_idx'));
    expect(migration, contains('where auth_user_id is not null'));
    expect(migration, contains("actor_kind in ('human', 'service_worker')"));
    expect(migration, contains('identity_bound_at is not null'));
    expect(runbook, contains('先にoperatorを無効化'));
  });

  test(
    'human RPCs derive operator identity and never accept an operator id',
    () {
      final claim = functionBody(
        'claim_my_ai_budget_reconciliation_cases',
        'release_my_ai_budget_reconciliation_claim',
      );
      final request = functionBody(
        'request_my_ai_budget_correction',
        'review_my_ai_budget_correction',
      );
      final resolve = functionBody(
        'resolve_my_ai_budget_reconciliation_case',
        'get_my_ai_budget_reconciliation_queue_metrics',
      );
      expect(claim, isNot(contains('p_operator_id')));
      expect(request, isNot(contains('p_operator_id')));
      expect(resolve, isNot(contains('p_operator_id')));
      expect(migration, contains('operator.auth_user_id = auth.uid()'));
      expect(
        migration,
        contains("auth.role() is distinct from 'authenticated'"),
      );
      expect(migration, contains('operator_identity_mismatch'));
    },
  );

  test('service workers cannot correct approve apply or resolve', () {
    expect(migration, contains('service_worker_operator_required'));
    expect(migration, contains("actor_kind = 'service_worker'"));
    expect(migration, contains("and operator_role = 'reviewer'"));
    expect(
      migration,
      contains('from public, anon, authenticated, service_role;'),
    );
    expect(runbook, contains('claimとreleaseだけ'));
  });

  test('corrections require distinct human auth identities', () {
    expect(migration, contains('enforce_ai_budget_correction_human_actors'));
    expect(
      migration,
      contains('budget_correction_same_identity_approval_forbidden'),
    );
    expect(migration, contains('correction_approver_must_apply'));
    expect(migration, contains('human_case_resolver_required'));
    expect(migration, contains("operator.actor_kind = 'human'"));
    expect(runbook, contains('同じAuth userでは実行できない'));
  });

  test('audit actor kind and hosted drill remain privacy safe', () {
    expect(migration, contains('set_ai_reconciliation_event_actor_kind'));
    expect(migration, contains("'human', 'service_worker', 'legacy_unbound'"));
    expect(runbook, contains('メールアドレス'));
    expect(runbook, contains('集計値とPASS/FAILだけ'));
    expect(runbook, contains('破壊的なdown migrationは実行しない'));
  });
}
