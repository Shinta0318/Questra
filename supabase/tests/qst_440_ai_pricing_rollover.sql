-- QST-440 hosted evidence. Run after the exact migration SHA is deployed.
begin;

select public.verify_ai_model_cost_rate_windows();

select public.ai_token_cost_micros_at(
  'gemini',
  'gemini-3.6-flash',
  1000000,
  1000000,
  timestamptz '2026-12-31 23:59:59+00'
) = 4500000 as old_rate_applies_before_boundary;

select public.ai_token_cost_micros_at(
  'gemini',
  'gemini-3.6-flash',
  1000000,
  1000000,
  timestamptz '2027-01-01 00:00:00+00'
) = 9000000 as new_rate_applies_at_boundary;

select count(*) = 0 as no_rate_window_gap_or_overlap
from (
  select provider,
    model_name,
    effective_from,
    lag(valid_until) over (
      partition by provider, model_name order by effective_from
    ) as previous_valid_until,
    row_number() over (
      partition by provider, model_name order by effective_from
    ) as sequence_number
  from public.ai_model_cost_rates
) as windows
where sequence_number > 1
  and previous_valid_until is distinct from effective_from;

select has_function_privilege(
  'authenticated',
  'public.ai_token_cost_micros_at(text,text,integer,integer,timestamptz)',
  'EXECUTE'
) = false as authenticated_cannot_call_pricing_function;

select has_function_privilege(
  'authenticated',
  'public.settle_ai_usage_budget(uuid,text,integer,integer,text)',
  'EXECUTE'
) = false as authenticated_cannot_settle_usage;

rollback;
