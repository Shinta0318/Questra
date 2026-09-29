begin;

create or replace function public.reserve_ai_usage_budget_v2(
  p_user_id uuid,
  p_operation text,
  p_idempotency_key text,
  p_provider text,
  p_model_names text[],
  p_estimated_input_tokens integer,
  p_max_output_tokens integer,
  p_trace_id uuid,
  p_abuse_key_hash text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_model_name text;
  v_requested_count integer;
  v_priced_count integer;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if coalesce(array_length(p_model_names, 1), 0) not between 1 and 4 then
    raise exception 'invalid_ai_model_candidates';
  end if;
  if exists (
    select 1
    from unnest(p_model_names) as candidate(model_name)
    where btrim(model_name) !~ '^[a-z0-9][a-z0-9._-]{2,79}$'
  ) then
    raise exception 'invalid_ai_model_candidate';
  end if;

  with requested as (
    select distinct btrim(model_name) as model_name
    from unnest(p_model_names) as candidate(model_name)
  )
  select count(*) into v_requested_count from requested;

  with requested as (
    select distinct btrim(model_name) as model_name
    from unnest(p_model_names) as candidate(model_name)
  ), active_rates as (
    select requested.model_name,
      rate.input_micros_per_million_tokens,
      rate.output_micros_per_million_tokens
    from requested
    join lateral (
      select input_micros_per_million_tokens,
        output_micros_per_million_tokens
      from public.ai_model_cost_rates
      where provider = p_provider
        and model_name = requested.model_name
        and effective_from <= now()
        and (valid_until is null or valid_until > now())
      order by effective_from desc
      limit 1
    ) as rate on true
  )
  select count(*) into v_priced_count from active_rates;

  if v_priced_count <> v_requested_count then
    raise exception 'ai_model_cost_rate_missing';
  end if;

  with requested as (
    select distinct btrim(model_name) as model_name
    from unnest(p_model_names) as candidate(model_name)
  )
  select requested.model_name into v_model_name
  from requested
  order by public.ai_token_cost_micros(
    p_provider,
    requested.model_name,
    greatest(p_estimated_input_tokens, 0),
    greatest(p_max_output_tokens, 1)
  ) desc, requested.model_name
  limit 1;

  return public.reserve_ai_usage_budget(
    p_user_id => p_user_id,
    p_operation => p_operation,
    p_idempotency_key => p_idempotency_key,
    p_provider => p_provider,
    p_model_name => v_model_name,
    p_estimated_input_tokens => p_estimated_input_tokens,
    p_max_output_tokens => p_max_output_tokens,
    p_trace_id => p_trace_id,
    p_abuse_key_hash => p_abuse_key_hash
  );
end;
$$;

revoke all on function public.reserve_ai_usage_budget_v2(
  uuid, text, text, text, text[], integer, integer, uuid, text
) from public;
grant execute on function public.reserve_ai_usage_budget_v2(
  uuid, text, text, text, text[], integer, integer, uuid, text
) to service_role;

commit;
