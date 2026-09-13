-- QST-442 hosted evidence. Run after the exact migration SHA is deployed.
begin;

select has_function_privilege(
  'authenticated',
  'public.purge_expired_ai_budget_evidence(integer,text)',
  'EXECUTE'
) = false as authenticated_cannot_run_retention;

select has_function_privilege(
  'authenticated',
  'public.set_ai_budget_evidence_legal_hold(uuid,timestamptz,text)',
  'EXECUTE'
) = false as authenticated_cannot_set_hold;

select relrowsecurity = true as retention_policy_rls_enabled
from pg_class
where oid = 'public.ai_evidence_retention_policies'::regclass;

select relrowsecurity = true as retention_audit_rls_enabled
from pg_class
where oid = 'public.ai_evidence_retention_runs'::regclass;

select policy_version, receipt_days, attempt_days, resolved_case_days, audit_days
from public.ai_evidence_retention_policies
where status = 'active';

select count(*) = 0 as expired_unheld_receipts_remaining
from public.ai_provider_execution_receipts receipt
where receipt.retention_until <= now()
  and (receipt.legal_hold_until is null or receipt.legal_hold_until <= now())
  and not exists (
    select 1 from public.ai_budget_reconciliation_cases review
    where review.reservation_id = receipt.reservation_id
      and review.status = 'open'
  );

select count(*) = 0 as audit_contains_no_identity_columns
from information_schema.columns
where table_schema = 'public'
  and table_name = 'ai_evidence_retention_runs'
  and column_name in (
    'user_id', 'owner_id', 'reservation_id', 'trace_id',
    'provider_interaction_id', 'prompt', 'response_body'
  );

rollback;
