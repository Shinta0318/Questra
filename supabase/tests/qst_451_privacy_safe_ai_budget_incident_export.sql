-- QST-451 hosted contract checks. Run after candidate deployment.
begin;

select has_table_privilege(
  'authenticated',
  'public.ai_budget_incident_exports',
  'SELECT'
) = false as clients_cannot_select_exports_directly;

select has_table_privilege(
  'authenticated',
  'public.ai_budget_incident_export_events',
  'SELECT'
) = false as clients_cannot_select_export_audit_directly;

select has_function_privilege(
  'authenticated',
  'public.generate_my_ai_budget_incident_export(date,date,text)',
  'EXECUTE'
) as authenticated_operator_can_request_export_rpc;

select position(
  'current_ai_reconciliation_operator'
  in pg_get_functiondef(
    'public.generate_my_ai_budget_incident_export(date,date,text)'::regprocedure
  )
) > 0 as generator_is_bound_to_authenticated_operator;

select position(
  'event_count >= v_policy.minimum_group_size'
  in pg_get_functiondef(
    'public.generate_my_ai_budget_incident_export(date,date,text)'::regprocedure
  )
) > 0 as small_groups_are_suppressed;

select count(*) = 0 as content_or_subject_columns_are_absent
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'ai_budget_incident_exports',
    'ai_budget_incident_export_events'
  )
  and column_name in (
    'prompt', 'response', 'quest_id', 'user_id', 'trace_id',
    'reservation_id', 'provider_interaction_id'
  );

select has_function_privilege(
  'authenticated',
  'public.expire_ai_budget_incident_exports()',
  'EXECUTE'
) = false as clients_cannot_run_retention_worker;

rollback;
