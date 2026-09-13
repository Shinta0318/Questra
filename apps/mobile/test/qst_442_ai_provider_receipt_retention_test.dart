import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609130003_ai_provider_receipt_retention.sql',
  ).readAsStringSync();
  final runbook = File(
    '${repo.path}/docs/product/ai_provider_receipt_retention.md',
  ).readAsStringSync();

  test('retention periods are versioned and purpose bounded', () {
    expect(migration, contains('ai_evidence_retention_policies'));
    expect(migration, contains("'2026-09-13.v1'"));
    expect(migration, contains("'active'"));
    expect(migration, contains("interval '90 days'"));
    expect(migration, contains("interval '180 days'"));
    expect(migration, contains("interval '365 days'"));
    expect(migration, contains("interval '730 days'"));
    expect(runbook, contains('Receipt: 90日'));
    expect(migration, contains('set_ai_evidence_row_retention'));
    expect(migration, contains('protect_ai_evidence_retention_policy_history'));
  });

  test('open cases and explicit holds prevent premature deletion', () {
    expect(migration, contains("review.status = 'open'"));
    expect(migration, contains('legal_hold_until > now()'));
    expect(migration, contains('set_ai_budget_evidence_legal_hold'));
    expect(migration, contains("'billing_dispute'"));
    expect(migration, contains("'security_incident'"));
    expect(migration, contains("'legal_request'"));
    expect(migration, contains("interval '10 years'"));
  });

  test('retention worker is bounded idempotent and metadata only', () {
    expect(migration, contains('purge_expired_ai_budget_evidence'));
    expect(migration, contains('p_limit not between 1 and 10000'));
    expect(migration, contains('for update skip locked'));
    expect(migration, contains('ai_evidence_retention_runs'));
    expect(migration, contains('run_reason'));
    expect(migration, contains("'scheduled_retention'"));
    expect(migration, contains("'manual_privacy_drill'"));
    expect(migration, contains('receipts_deleted'));
    expect(migration, contains('rows_held'));
    expect(migration, isNot(contains('provider_interaction_id text')));
    expect(migration, isNot(contains('prompt_content')));
    expect(migration, isNot(contains('response_body')));
  });

  test('client roles cannot operate retention or read audit tables', () {
    expect(migration, contains("auth.role() is distinct from 'service_role'"));
    expect(
      migration,
      contains('revoke all on public.ai_evidence_retention_policies'),
    );
    expect(
      migration,
      contains('revoke all on public.ai_evidence_retention_runs'),
    );
    expect(
      migration,
      contains(
        'grant execute on function '
        'public.purge_expired_ai_budget_evidence(integer, text)',
      ),
    );
    expect(migration, contains('to service_role;'));
  });

  test('account deletion and legal review boundary remain explicit', () {
    expect(runbook, contains('cascadeを優先'));
    expect(runbook, contains('法務承認を推測しない'));
    expect(runbook, contains('hosted実行前はExternal BetaをGOにしない'));
  });
}
