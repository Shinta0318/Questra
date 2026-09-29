-- QST-441 hosted evidence. Run after the exact migration SHA is deployed.
begin;

select has_function_privilege(
  'authenticated',
  'public.record_ai_provider_execution_receipt(uuid,text,text,integer,integer,text,uuid)',
  'EXECUTE'
) = false as authenticated_cannot_record_provider_receipt;

select has_function_privilege(
  'authenticated',
  'public.reconcile_ai_usage_budget(uuid)',
  'EXECUTE'
) = false as authenticated_cannot_reconcile_budget;

select has_function_privilege(
  'authenticated',
  'public.classify_stale_ai_budget_reservations(interval,integer)',
  'EXECUTE'
) = false as authenticated_cannot_sweep_reservations;

select relrowsecurity = true as receipt_rls_enabled
from pg_class
where oid = 'public.ai_provider_execution_receipts'::regclass;

select relrowsecurity = true as attempt_rls_enabled
from pg_class
where oid = 'public.ai_budget_reconciliation_attempts'::regclass;

select relrowsecurity = true as case_rls_enabled
from pg_class
where oid = 'public.ai_budget_reconciliation_cases'::regclass;

select count(*) = 0 as receipt_contains_no_content_columns
from information_schema.columns
where table_schema = 'public'
  and table_name = 'ai_provider_execution_receipts'
  and column_name in ('prompt', 'prompt_content', 'response_body', 'provider_output');

select count(*) = 0 as provider_interactions_are_not_reused
from (
  select provider, provider_interaction_id
  from public.ai_provider_execution_receipts
  where provider_interaction_id is not null
  group by provider, provider_interaction_id
  having count(*) > 1
) as duplicate_interactions;

select count(*) as open_operator_cases
from public.ai_budget_reconciliation_cases
where status = 'open';

rollback;
