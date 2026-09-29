-- QST-443 hosted contract checks. Execute after the candidate migration is
-- deployed. These checks do not claim or mutate a live reconciliation case.
begin;

select has_function_privilege(
  'authenticated',
  'public.claim_ai_budget_reconciliation_cases(uuid,integer,interval)',
  'EXECUTE'
) = false as authenticated_cannot_claim_cases;

select has_function_privilege(
  'authenticated',
  'public.request_ai_budget_correction(uuid,uuid,text,integer,integer,text,text)',
  'EXECUTE'
) = false as authenticated_cannot_request_correction;

select has_function_privilege(
  'authenticated',
  'public.apply_ai_budget_correction(uuid,uuid)',
  'EXECUTE'
) = false as authenticated_cannot_apply_correction;

select has_function_privilege(
  'authenticated',
  'public.get_ai_budget_reconciliation_queue_metrics(interval)',
  'EXECUTE'
) = false as authenticated_cannot_read_queue_metrics;

select relrowsecurity = true as operators_rls_enabled
from pg_class
where oid = 'public.ai_budget_reconciliation_operators'::regclass;

select relrowsecurity = true as events_rls_enabled
from pg_class
where oid = 'public.ai_budget_reconciliation_operator_events'::regclass;

select relrowsecurity = true as correction_requests_rls_enabled
from pg_class
where oid = 'public.ai_budget_correction_requests'::regclass;

select count(*) = 0 as resolution_notes_are_empty
from public.ai_budget_reconciliation_cases
where resolution_note is not null;

select count(*) = 0 as invalid_self_approvals
from public.ai_budget_correction_requests
where approved_by = requested_by;

select count(*) = 0 as multiple_active_corrections
from (
  select reservation_id
  from public.ai_budget_correction_requests
  where status in ('pending_approval', 'approved')
  group by reservation_id
  having count(*) > 1
) duplicate_active;

rollback;
