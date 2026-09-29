-- QST-448 hosted contract checks. Run after deploying the candidate migration.
-- This transaction does not invoke Gemini or create provider search traffic.
begin;

select exists (
  select 1
  from public.ai_grounding_cost_rates
  where provider = 'gemini'
    and tool_name = 'google_search'
    and rate_version = 'gemini_google_search_query_20260913'
    and billing_unit = 'unique_non_empty_query'
    and micros_per_unit = 14000
) as versioned_grounding_rate_exists;

select count(*) = 0 as grounding_ledger_has_no_content_columns
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'ai_grounding_budget_reservations',
    'ai_grounding_monthly_counters'
  )
  and column_name in (
    'query', 'query_text', 'url', 'source_uri', 'user_id', 'quest_id',
    'mission_id', 'prompt', 'response', 'content'
  );

select count(*) = 3 as all_grounding_tables_enable_rls
from pg_class
where oid in (
  'public.ai_grounding_cost_rates'::regclass,
  'public.ai_grounding_budget_reservations'::regclass,
  'public.ai_grounding_monthly_counters'::regclass
)
  and relrowsecurity = true;

select has_function_privilege(
  'authenticated',
  'public.reserve_ai_grounding_budget(uuid,integer)',
  'EXECUTE'
) = false as client_cannot_reserve_grounding_budget;

select has_function_privilege(
  'service_role',
  'public.reserve_ai_grounding_budget(uuid,integer)',
  'EXECUTE'
) as service_can_reserve_grounding_budget;

select position(
  'provider_execution_receipt_required'
  in pg_get_functiondef(
    'public.settle_ai_usage_budget(uuid,text,integer,integer,text)'::regprocedure
  )
) > 0 as settlement_requires_provider_receipt;

select position(
  'ai_grounding_query_count_exceeds_reservation'
  in pg_get_functiondef(
    'public.settle_ai_usage_budget(uuid,text,integer,integer,text)'::regprocedure
  )
) > 0 as settlement_rejects_unreserved_queries;

select position(
  'ai_grounding_provider_evidence_required'
  in pg_get_functiondef(
    'public.settle_ai_usage_budget(uuid,text,integer,integer,text)'::regprocedure
  )
) > 0 as grounding_settlement_requires_v2_provider_evidence;

select position(
  'new.status in (''released'', ''expired'')'
  in lower(pg_get_functiondef(
    'public.release_grounding_reservation_with_base()'::regprocedure
  ))
) > 0 as release_and_expiry_reclaim_grounding_reservation;

rollback;
