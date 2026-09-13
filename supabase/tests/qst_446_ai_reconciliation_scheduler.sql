-- QST-446 hosted contract checks. Execute after the candidate migration is
-- deployed. These queries do not enable or invoke the scheduler.
begin;

select enabled = false as scheduler_kill_switch_defaults_off
from public.ai_budget_reconciliation_worker_control
where id = 'scheduler';

select enabled = false and actor_kind = 'service_worker'
  as scheduler_identity_defaults_disabled
from public.ai_budget_reconciliation_operators
where operator_key = 'ai-budget-reconciliation-scheduler';

select has_function_privilege(
  'authenticated',
  'public.run_ai_budget_reconciliation_scheduler(text)',
  'EXECUTE'
) = false as authenticated_cannot_run_scheduler;

select has_function_privilege(
  'service_role',
  'public.run_ai_budget_reconciliation_scheduler(text)',
  'EXECUTE'
) as service_role_can_run_scheduler;

select relrowsecurity = true as worker_control_rls_enabled
from pg_class
where oid = 'public.ai_budget_reconciliation_worker_control'::regclass;

select relrowsecurity = true as worker_runs_rls_enabled
from pg_class
where oid = 'public.ai_budget_reconciliation_worker_runs'::regclass;

select relrowsecurity = true as scheduler_alerts_rls_enabled
from pg_class
where oid = 'public.ai_budget_reconciliation_sla_alerts'::regclass;

select count(*) = 0 as alerts_store_no_direct_identifiers
from information_schema.columns
where table_schema = 'public'
  and table_name = 'ai_budget_reconciliation_sla_alerts'
  and column_name in (
    'user_id', 'owner_id', 'quest_id', 'reservation_id',
    'trace_id', 'provider_interaction_id', 'prompt', 'response', 'content'
  );

select position(
  'classify_stale_ai_budget_reservations'
  in pg_get_functiondef(
    'public.run_ai_budget_reconciliation_scheduler(text)'::regprocedure
  )
) > 0 as scheduler_reuses_receipt_aware_classifier;

select position(
  'FOR UPDATE SKIP LOCKED'
  in upper(pg_get_functiondef(
    'public.claim_ai_budget_reconciliation_sla_alerts(integer)'::regprocedure
  ))
) > 0 as alert_delivery_claim_is_lock_safe;

select count(*) = 0 as scheduler_has_no_unbounded_failed_alerts
from public.ai_budget_reconciliation_sla_alerts
where delivery_attempts > 20;

rollback;
