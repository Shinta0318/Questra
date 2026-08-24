begin;

alter table public.ai_usage_policies
  add column if not exists monthly_cost_hard_limit_micros bigint,
  add column if not exists per_minute_hard_limit integer;

update public.ai_usage_policies
set monthly_hard_limit = case operation
      when 'arc_consultation' then case subscription_state when 'premium' then 1500 else 300 end
      when 'quest_planning' then case subscription_state when 'premium' then 150 else 30 end
      when 'basic_mission_planning' then case subscription_state when 'premium' then 300 else 60 end
      when 'mission_redesign' then case subscription_state when 'premium' then 150 else 30 end
      when 'detailed_progress_review' then case subscription_state when 'premium' then 100 else 20 end
    end,
    monthly_cost_hard_limit_micros = case subscription_state
      when 'premium' then 20000000
      when 'grace_period' then 5000000
      else 2000000
    end,
    per_minute_hard_limit = case subscription_state when 'premium' then 20 else 10 end;

alter table public.ai_usage_policies
  alter column monthly_hard_limit set not null,
  alter column monthly_cost_hard_limit_micros set not null,
  alter column per_minute_hard_limit set not null,
  add constraint ai_usage_policies_cost_limit_positive
    check (monthly_cost_hard_limit_micros > 0),
  add constraint ai_usage_policies_minute_limit_positive
    check (per_minute_hard_limit > 0);

create table if not exists public.ai_operation_controls (
  operation text primary key,
  enabled boolean not null default true,
  disabled_reason text check (
    disabled_reason is null or char_length(disabled_reason) between 1 and 160
  ),
  updated_at timestamptz not null default now()
);

alter table public.ai_operation_controls
  add constraint ai_operation_controls_operation_check check (operation in (
    'arc_consultation', 'quest_planning', 'basic_mission_planning',
    'mission_redesign', 'detailed_progress_review'
  ));

insert into public.ai_operation_controls (operation)
select unnest(array[
  'arc_consultation', 'quest_planning', 'basic_mission_planning',
  'mission_redesign', 'detailed_progress_review'
])
on conflict (operation) do nothing;

create table if not exists public.ai_model_cost_rates (
  provider text not null check (provider in ('gemini', 'openai')),
  model_name text not null check (char_length(model_name) between 1 and 120),
  input_micros_per_million_tokens bigint not null check (
    input_micros_per_million_tokens >= 0
  ),
  output_micros_per_million_tokens bigint not null check (
    output_micros_per_million_tokens >= 0
  ),
  source_uri text not null check (source_uri like 'https://%'),
  effective_from timestamptz not null,
  valid_until timestamptz,
  updated_at timestamptz not null default now(),
  primary key (provider, model_name, effective_from),
  check (valid_until is null or valid_until > effective_from)
);

-- USD micros per 1M text tokens. Rates are versioned from Google's official
-- pricing page; expired rates fail closed until an operator adds a successor.
insert into public.ai_model_cost_rates (
  provider, model_name, input_micros_per_million_tokens,
  output_micros_per_million_tokens, source_uri, effective_from, valid_until
) values
  ('gemini', 'gemini-3.6-flash', 750000, 3750000,
   'https://ai.google.dev/gemini-api/docs/pricing', '2026-08-01', '2027-01-01'),
  ('gemini', 'gemini-3.5-flash', 1500000, 9000000,
   'https://ai.google.dev/gemini-api/docs/pricing', '2026-08-01', null),
  ('gemini', 'gemini-3.5-flash-lite', 300000, 2500000,
   'https://ai.google.dev/gemini-api/docs/pricing', '2026-08-01', null),
  ('gemini', 'gemini-3.1-pro-preview', 2000000, 12000000,
   'https://ai.google.dev/gemini-api/docs/pricing', '2026-08-01', null)
on conflict (provider, model_name, effective_from) do update set
  input_micros_per_million_tokens = excluded.input_micros_per_million_tokens,
  output_micros_per_million_tokens = excluded.output_micros_per_million_tokens,
  source_uri = excluded.source_uri,
  valid_until = excluded.valid_until,
  updated_at = now();

create table if not exists public.ai_budget_reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null check (operation in (
    'arc_consultation', 'quest_planning', 'basic_mission_planning',
    'mission_redesign', 'detailed_progress_review'
  )),
  idempotency_key text not null check (char_length(idempotency_key) between 8 and 240),
  trace_id uuid not null,
  provider text not null check (provider in ('gemini', 'openai')),
  model_name text not null check (char_length(model_name) between 1 and 120),
  status text not null default 'reserved' check (
    status in ('reserved', 'settled', 'released', 'expired')
  ),
  estimated_input_tokens integer not null check (estimated_input_tokens between 0 and 200000),
  reserved_output_tokens integer not null check (reserved_output_tokens between 1 and 200000),
  actual_input_tokens integer check (actual_input_tokens between 0 and 200000),
  actual_output_tokens integer check (actual_output_tokens between 0 and 200000),
  reserved_cost_micros bigint not null check (reserved_cost_micros >= 0),
  actual_cost_micros bigint check (actual_cost_micros is null or actual_cost_micros >= 0),
  abuse_key_hash text check (
    abuse_key_hash is null or abuse_key_hash ~ '^[0-9a-f]{64}$'
  ),
  finish_reason text check (finish_reason is null or char_length(finish_reason) <= 80),
  release_reason text check (release_reason is null or char_length(release_reason) <= 80),
  period_start date not null,
  reserved_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '10 minutes'),
  settled_at timestamptz,
  released_at timestamptz,
  admission_latency_ms integer not null default 0 check (
    admission_latency_ms between 0 and 10000
  ),
  unique (user_id, operation, idempotency_key)
);

create index if not exists ai_budget_reservations_user_period_idx
  on public.ai_budget_reservations (user_id, operation, period_start, status);
create index if not exists ai_budget_reservations_abuse_minute_idx
  on public.ai_budget_reservations (abuse_key_hash, reserved_at desc)
  where abuse_key_hash is not null;

alter table public.ai_usage_counters
  add column if not exists reserved_count integer not null default 0 check (reserved_count >= 0),
  add column if not exists settled_count integer not null default 0 check (settled_count >= 0),
  add column if not exists reserved_cost_micros bigint not null default 0 check (reserved_cost_micros >= 0),
  add column if not exists actual_cost_micros bigint not null default 0 check (actual_cost_micros >= 0);

create table if not exists public.ai_budget_alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  operation text not null,
  alert_type text not null check (alert_type in (
    'monthly_request_limit', 'monthly_cost_limit', 'per_minute_limit',
    'network_abuse_limit', 'ai_disabled', 'settlement_failed'
  )),
  observed_value bigint,
  limit_value bigint,
  trace_id uuid,
  alert_day date not null default current_date,
  created_at timestamptz not null default now(),
  unique (user_id, operation, alert_type, alert_day)
);

alter table public.ai_operation_controls enable row level security;
alter table public.ai_model_cost_rates enable row level security;
alter table public.ai_budget_reservations enable row level security;
alter table public.ai_budget_alerts enable row level security;

drop policy if exists ai_budget_reservations_owner_select on public.ai_budget_reservations;
create policy ai_budget_reservations_owner_select
  on public.ai_budget_reservations for select using (user_id = auth.uid());

revoke all on public.ai_operation_controls from anon, authenticated;
revoke all on public.ai_model_cost_rates from anon, authenticated;
revoke all on public.ai_budget_reservations from anon, authenticated;
revoke all on public.ai_budget_alerts from anon, authenticated;
grant select on public.ai_budget_reservations to authenticated;

create or replace view public.ai_usage_cost_daily
with (security_invoker = true)
as
select
  date_trunc('day', reserved_at) as usage_day,
  operation,
  provider,
  model_name,
  count(*) filter (where status = 'settled') as settled_calls,
  count(*) filter (where status = 'released') as released_calls,
  coalesce(sum(actual_input_tokens) filter (where status = 'settled'), 0) as input_tokens,
  coalesce(sum(actual_output_tokens) filter (where status = 'settled'), 0) as output_tokens,
  coalesce(sum(actual_cost_micros) filter (where status = 'settled'), 0) as actual_cost_micros,
  percentile_cont(0.95) within group (order by admission_latency_ms) as admission_p95_ms
from public.ai_budget_reservations
group by date_trunc('day', reserved_at), operation, provider, model_name;

revoke all on public.ai_usage_cost_daily from anon, authenticated;
grant select on public.ai_usage_cost_daily to service_role;

create or replace function public.ai_token_cost_micros(
  p_provider text,
  p_model_name text,
  p_input_tokens integer,
  p_output_tokens integer
) returns bigint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_input_rate bigint;
  v_output_rate bigint;
begin
  select input_micros_per_million_tokens, output_micros_per_million_tokens
    into v_input_rate, v_output_rate
  from public.ai_model_cost_rates
  where provider = p_provider
    and model_name = p_model_name
    and effective_from <= now()
    and (valid_until is null or valid_until > now())
  order by effective_from desc
  limit 1;
  if not found then raise exception 'ai_model_cost_rate_missing'; end if;
  return ceil(
    (greatest(p_input_tokens, 0)::numeric * v_input_rate +
     greatest(p_output_tokens, 0)::numeric * v_output_rate) / 1000000
  )::bigint;
end;
$$;

create or replace function public.reserve_ai_usage_budget(
  p_user_id uuid,
  p_operation text,
  p_idempotency_key text,
  p_provider text,
  p_model_name text,
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
  v_started_at timestamptz := clock_timestamp();
  v_state text;
  v_request_limit integer;
  v_cost_limit bigint;
  v_minute_limit integer;
  v_period date := date_trunc('month', now())::date;
  v_existing public.ai_budget_reservations%rowtype;
  v_month_requests integer;
  v_minute_requests integer;
  v_ip_minute_requests integer;
  v_month_cost bigint;
  v_reserved_cost bigint;
  v_id uuid := gen_random_uuid();
begin
  if auth.role() is distinct from 'service_role' then raise exception 'service_role_required'; end if;
  if p_operation not in (
    'arc_consultation', 'quest_planning', 'basic_mission_planning',
    'mission_redesign', 'detailed_progress_review'
  ) then raise exception 'unsupported_ai_operation'; end if;
  if char_length(p_idempotency_key) not between 8 and 240 then
    raise exception 'invalid_idempotency_key';
  end if;
  if p_abuse_key_hash is not null and p_abuse_key_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_abuse_key_hash';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    p_user_id::text || ':' || p_operation || ':' || v_period::text, 0
  ));

  select * into v_existing from public.ai_budget_reservations
  where user_id = p_user_id and operation = p_operation
    and idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object(
      'allowed', false,
      'reservation_id', v_existing.id,
      'reason', case when v_existing.status = 'settled'
        then 'idempotency_already_settled' else 'idempotency_in_progress' end,
      'resets_at', v_period + interval '1 month'
    );
  end if;

  if not exists (
    select 1 from public.ai_operation_controls
    where operation = p_operation and enabled
  ) then
    insert into public.ai_budget_alerts (
      user_id, operation, alert_type, trace_id
    ) values (p_user_id, p_operation, 'ai_disabled', p_trace_id)
    on conflict (user_id, operation, alert_type, alert_day) do nothing;
    return jsonb_build_object('allowed', false, 'reason', 'ai_disabled');
  end if;

  select case when expires_at is not null and expires_at <= now()
      then 'free' else subscription_state end
    into v_state
  from public.user_entitlements where user_id = p_user_id;
  v_state := coalesce(v_state, 'free');

  select monthly_hard_limit, monthly_cost_hard_limit_micros,
      per_minute_hard_limit
    into v_request_limit, v_cost_limit, v_minute_limit
  from public.ai_usage_policies
  where operation = p_operation and subscription_state = v_state and enabled;
  if not found then raise exception 'ai_usage_policy_not_configured'; end if;

  v_reserved_cost := public.ai_token_cost_micros(
    p_provider, p_model_name, p_estimated_input_tokens, p_max_output_tokens
  );
  select count(*), coalesce(sum(case when status = 'settled'
      then actual_cost_micros else reserved_cost_micros end), 0)
    into v_month_requests, v_month_cost
  from public.ai_budget_reservations
  where user_id = p_user_id and operation = p_operation
    and period_start = v_period
    and (status = 'settled' or (status = 'reserved' and expires_at > now()));

  if v_month_requests >= v_request_limit then
    insert into public.ai_budget_alerts (
      user_id, operation, alert_type, observed_value, limit_value, trace_id
    ) values (
      p_user_id, p_operation, 'monthly_request_limit', v_month_requests,
      v_request_limit, p_trace_id
    ) on conflict (user_id, operation, alert_type, alert_day) do nothing;
    return jsonb_build_object('allowed', false, 'reason', 'monthly_request_limit',
      'resets_at', v_period + interval '1 month');
  end if;
  if v_month_cost + v_reserved_cost > v_cost_limit then
    insert into public.ai_budget_alerts (
      user_id, operation, alert_type, observed_value, limit_value, trace_id
    ) values (
      p_user_id, p_operation, 'monthly_cost_limit',
      v_month_cost + v_reserved_cost, v_cost_limit, p_trace_id
    ) on conflict (user_id, operation, alert_type, alert_day) do nothing;
    return jsonb_build_object('allowed', false, 'reason', 'monthly_cost_limit',
      'resets_at', v_period + interval '1 month');
  end if;

  select count(*) into v_minute_requests
  from public.ai_budget_reservations
  where user_id = p_user_id and reserved_at >= now() - interval '1 minute'
    and (status = 'settled' or (status = 'reserved' and expires_at > now()));
  if v_minute_requests >= v_minute_limit then
    insert into public.ai_budget_alerts (
      user_id, operation, alert_type, observed_value, limit_value, trace_id
    ) values (
      p_user_id, p_operation, 'per_minute_limit', v_minute_requests,
      v_minute_limit, p_trace_id
    ) on conflict (user_id, operation, alert_type, alert_day) do nothing;
    return jsonb_build_object('allowed', false, 'reason', 'per_minute_limit');
  end if;

  if p_abuse_key_hash is not null then
    perform pg_advisory_xact_lock(hashtextextended(p_abuse_key_hash, 0));
    select count(*) into v_ip_minute_requests
    from public.ai_budget_reservations
    where abuse_key_hash = p_abuse_key_hash
      and reserved_at >= now() - interval '1 minute'
      and (status = 'settled' or (status = 'reserved' and expires_at > now()));
    if v_ip_minute_requests >= greatest(v_minute_limit * 3, 20) then
      insert into public.ai_budget_alerts (
        user_id, operation, alert_type, observed_value, limit_value, trace_id
      ) values (
        p_user_id, p_operation, 'network_abuse_limit', v_ip_minute_requests,
        greatest(v_minute_limit * 3, 20), p_trace_id
      ) on conflict (user_id, operation, alert_type, alert_day) do nothing;
      return jsonb_build_object('allowed', false, 'reason', 'network_abuse_limit');
    end if;
  end if;

  insert into public.ai_budget_reservations (
    id, user_id, operation, idempotency_key, trace_id, provider, model_name,
    estimated_input_tokens, reserved_output_tokens, reserved_cost_micros,
    abuse_key_hash, period_start, admission_latency_ms
  ) values (
    v_id, p_user_id, p_operation, p_idempotency_key, p_trace_id, p_provider,
    p_model_name, greatest(p_estimated_input_tokens, 0),
    greatest(p_max_output_tokens, 1), v_reserved_cost, p_abuse_key_hash, v_period,
    least(10000, greatest(0, floor(extract(epoch from (
      clock_timestamp() - v_started_at
    )) * 1000)::integer))
  );
  insert into public.ai_usage_counters (
    user_id, operation, period_start, usage_count, reserved_count,
    reserved_cost_micros
  ) values (p_user_id, p_operation, v_period, 1, 1, v_reserved_cost)
  on conflict (user_id, operation, period_start) do update set
    usage_count = public.ai_usage_counters.usage_count + 1,
    reserved_count = public.ai_usage_counters.reserved_count + 1,
    reserved_cost_micros = public.ai_usage_counters.reserved_cost_micros + v_reserved_cost,
    updated_at = now();

  return jsonb_build_object('allowed', true, 'reservation_id', v_id,
    'reason', 'reserved', 'resets_at', v_period + interval '1 month');
end;
$$;

create or replace function public.settle_ai_usage_budget(
  p_reservation_id uuid,
  p_model_name text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_finish_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.ai_budget_reservations%rowtype;
  v_cost bigint;
begin
  if auth.role() is distinct from 'service_role' then raise exception 'service_role_required'; end if;
  select * into v_row from public.ai_budget_reservations
  where id = p_reservation_id for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;
  if v_row.status = 'settled' then
    return jsonb_build_object('settled', true, 'idempotent', true,
      'actual_cost_micros', v_row.actual_cost_micros);
  end if;
  if v_row.status <> 'reserved' then raise exception 'ai_reservation_not_settleable'; end if;
  v_cost := public.ai_token_cost_micros(
    v_row.provider, p_model_name, greatest(p_input_tokens, 0),
    greatest(p_output_tokens, 0)
  );
  update public.ai_budget_reservations set
    status = 'settled', model_name = p_model_name,
    actual_input_tokens = greatest(p_input_tokens, 0),
    actual_output_tokens = greatest(p_output_tokens, 0),
    actual_cost_micros = v_cost,
    finish_reason = left(p_finish_reason, 80), settled_at = now()
  where id = p_reservation_id;
  update public.ai_usage_counters set
    reserved_count = greatest(reserved_count - 1, 0),
    settled_count = settled_count + 1,
    reserved_cost_micros = greatest(reserved_cost_micros - v_row.reserved_cost_micros, 0),
    actual_cost_micros = actual_cost_micros + v_cost,
    updated_at = now()
  where user_id = v_row.user_id and operation = v_row.operation
    and period_start = v_row.period_start;
  return jsonb_build_object('settled', true, 'idempotent', false,
    'actual_cost_micros', v_cost);
end;
$$;

create or replace function public.release_ai_usage_budget(
  p_reservation_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.ai_budget_reservations%rowtype;
begin
  if auth.role() is distinct from 'service_role' then raise exception 'service_role_required'; end if;
  select * into v_row from public.ai_budget_reservations
  where id = p_reservation_id for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;
  if v_row.status = 'released' then
    return jsonb_build_object('released', true, 'idempotent', true);
  end if;
  if v_row.status <> 'reserved' then raise exception 'ai_reservation_not_releasable'; end if;
  update public.ai_budget_reservations set
    status = 'released', release_reason = left(p_reason, 80), released_at = now()
  where id = p_reservation_id;
  update public.ai_usage_counters set
    usage_count = greatest(usage_count - 1, 0),
    reserved_count = greatest(reserved_count - 1, 0),
    reserved_cost_micros = greatest(reserved_cost_micros - v_row.reserved_cost_micros, 0),
    updated_at = now()
  where user_id = v_row.user_id and operation = v_row.operation
    and period_start = v_row.period_start;
  return jsonb_build_object('released', true, 'idempotent', false);
end;
$$;

revoke all on function public.ai_token_cost_micros(text, text, integer, integer) from public;
revoke all on function public.reserve_ai_usage_budget(uuid, text, text, text, text, integer, integer, uuid, text) from public;
revoke all on function public.settle_ai_usage_budget(uuid, text, integer, integer, text) from public;
revoke all on function public.release_ai_usage_budget(uuid, text) from public;
grant execute on function public.reserve_ai_usage_budget(uuid, text, text, text, text, integer, integer, uuid, text) to service_role;
grant execute on function public.settle_ai_usage_budget(uuid, text, integer, integer, text) to service_role;
grant execute on function public.release_ai_usage_budget(uuid, text) to service_role;

commit;
