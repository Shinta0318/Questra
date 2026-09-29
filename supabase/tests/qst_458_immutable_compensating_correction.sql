begin;

select has_column(
  'public',
  'ai_budget_correction_requests',
  'compensates_request_id',
  'correction requests retain an explicit compensation link'
);

select has_function(
  'public',
  'request_my_compensating_ai_budget_correction',
  array['uuid', 'text'],
  'authenticated operators have a typed compensation entry point'
);

select function_privs_are(
  'public',
  'request_compensating_ai_budget_correction',
  array['uuid', 'uuid', 'text'],
  'service_role',
  array[]::text[],
  'service role cannot impersonate a human compensation requester'
);

select function_privs_are(
  'public',
  'request_my_compensating_ai_budget_correction',
  array['uuid', 'text'],
  'authenticated',
  array['EXECUTE'],
  'authenticated operators can call only the auth-bound wrapper'
);

select count(*) = 1 as one_compensation_unique_index_present
from pg_indexes
where schemaname = 'public'
  and tablename = 'ai_budget_correction_requests'
  and indexname = 'ai_budget_correction_one_compensation_idx'
  and indexdef ilike '%unique%'
  and indexdef ilike '%compensates_request_id%';

select pg_get_functiondef(
  'public.request_compensating_ai_budget_correction(uuid,uuid,text)'::regprocedure
) ilike '%for update%'
  and pg_get_functiondef(
    'public.request_compensating_ai_budget_correction(uuid,uuid,text)'::regprocedure
  ) ilike '%budget_compensation_stale_snapshot%'
  and pg_get_functiondef(
    'public.request_compensating_ai_budget_correction(uuid,uuid,text)'::regprocedure
  ) ilike '%pending_approval%'
  and pg_get_functiondef(
    'public.request_compensating_ai_budget_correction(uuid,uuid,text)'::regprocedure
  ) not ilike '%update public.ai_usage_counters%'
  as compensation_is_locked_stale_safe_and_non_mutating;

select pg_get_functiondef(
  'public.request_my_compensating_ai_budget_correction(uuid,text)'::regprocedure
) ilike '%current_ai_reconciliation_operator(''reviewer'')%'
  as compensation_requester_is_auth_bound_reviewer;

rollback;
