-- QST-449 hosted contract checks. Run after deploying the candidate migration.
-- The transaction only inspects aggregate contracts and rolls back.
begin;

select count(*) = 3 as anomaly_tables_enable_rls
from pg_class
where oid in (
  'public.ai_cost_anomaly_policies'::regclass,
  'public.ai_cost_anomaly_alerts'::regclass,
  'public.ai_operation_control_audit'::regclass
)
  and relrowsecurity = true;

select has_function_privilege(
  'authenticated',
  'public.detect_ai_cost_anomalies(date)',
  'EXECUTE'
) = false as client_cannot_run_cost_detection;

select has_function_privilege(
  'authenticated',
  'public.set_ai_operation_control(text,boolean,text,uuid)',
  'EXECUTE'
) = false as client_cannot_change_ai_operation_control;

select position(
  'update public.ai_operation_controls'
  in lower(pg_get_functiondef(
    'public.detect_ai_cost_anomalies(date)'::regprocedure
  ))
) = 0 as anomaly_detection_does_not_auto_disable_operations;

select position(
  'ai_provider_thinking_evidence_required'
  in pg_get_functiondef(
    'public.require_ai_receipt_thinking_evidence()'::regprocedure
  )
) > 0 as settlement_requires_thinking_evidence;

select count(*) = 0 as anomaly_alert_has_no_journey_identifier_columns
from information_schema.columns
where table_schema = 'public'
  and table_name = 'ai_cost_anomaly_alerts'
  and column_name in (
    'user_id', 'owner_id', 'quest_id', 'mission_id', 'trace_id',
    'prompt', 'response', 'provider_interaction_id'
  );

rollback;
