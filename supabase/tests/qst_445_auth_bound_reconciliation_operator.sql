-- QST-445 hosted contract checks. Execute after the candidate migration is
-- deployed. No live queue item is claimed or modified by this contract check.
begin;

select count(*) = 0 as enabled_humans_are_auth_bound
from public.ai_budget_reconciliation_operators
where enabled
  and actor_kind = 'human'
  and (auth_user_id is null or identity_bound_at is null);

select count(*) = 0 as duplicate_human_auth_bindings
from (
  select auth_user_id
  from public.ai_budget_reconciliation_operators
  where auth_user_id is not null
  group by auth_user_id
  having count(*) > 1
) duplicate_binding;

select count(*) = 0 as service_workers_have_no_human_authority
from public.ai_budget_reconciliation_operators
where actor_kind = 'service_worker'
  and (auth_user_id is not null or operator_role <> 'reviewer');

select has_function_privilege(
  'authenticated',
  'public.claim_my_ai_budget_reconciliation_cases(integer,interval)',
  'EXECUTE'
) as authenticated_can_invoke_guarded_claim_wrapper;

select has_function_privilege(
  'authenticated',
  'public.claim_ai_budget_reconciliation_cases(uuid,integer,interval)',
  'EXECUTE'
) = false as authenticated_cannot_supply_operator_id;

select has_function_privilege(
  'service_role',
  'public.request_ai_budget_correction(uuid,uuid,text,integer,integer,text,text)',
  'EXECUTE'
) = false as service_worker_cannot_request_correction;

select has_function_privilege(
  'service_role',
  'public.resolve_ai_budget_reconciliation_case(uuid,uuid,text,text)',
  'EXECUTE'
) = false as service_worker_cannot_resolve_case;

select position(
  'operator.auth_user_id = auth.uid()'
  in pg_get_functiondef(
    'public.current_ai_reconciliation_operator(text)'::regprocedure
  )
) > 0 as current_operator_is_auth_bound;

select count(*) = 0 as same_auth_identity_corrections_absent
from public.ai_budget_correction_requests correction
join public.ai_budget_reconciliation_operators requester
  on requester.id = correction.requested_by
join public.ai_budget_reconciliation_operators approver
  on approver.id = correction.approved_by
where requester.auth_user_id = approver.auth_user_id;

select count(*) = 0 as event_actor_kind_is_valid
from public.ai_budget_reconciliation_operator_events
where actor_kind not in ('human', 'service_worker', 'legacy_unbound');

rollback;
