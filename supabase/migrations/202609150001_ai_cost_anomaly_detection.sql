begin;

alter table public.ai_provider_execution_receipts
  add column if not exists thinking_level text not null default 'unknown';

alter table public.ai_provider_execution_receipts
  drop constraint if exists ai_provider_receipt_thinking_level_check,
  add constraint ai_provider_receipt_thinking_level_check check (
    thinking_level in ('unknown', 'minimal', 'low', 'medium', 'high')
  );

create table if not exists public.ai_cost_anomaly_policies (
  policy_version text primary key check (
    policy_version ~ '^[a-z0-9][a-z0-9._-]{7,79}$'
  ),
  active boolean not null default false,
  baseline_days integer not null check (baseline_days between 3 and 30),
  minimum_history_days integer not null check (
    minimum_history_days between 2 and baseline_days
  ),
  increase_multiplier numeric(8, 3) not null check (
    increase_multiplier between 1.1 and 100
  ),
  minimum_cost_delta_micros bigint not null check (
    minimum_cost_delta_micros >= 0
  ),
  minimum_settled_calls integer not null check (
    minimum_settled_calls between 1 and 100000
  ),
  created_at timestamptz not null default now()
);

create unique index if not exists ai_cost_anomaly_one_active_policy_idx
  on public.ai_cost_anomaly_policies (active)
  where active;

insert into public.ai_cost_anomaly_policies (
  policy_version,
  active,
  baseline_days,
  minimum_history_days,
  increase_multiplier,
  minimum_cost_delta_micros,
  minimum_settled_calls
) values (
  'ai_cost_anomaly_20260915_v1',
  true,
  7,
  3,
  2.0,
  100000,
  3
) on conflict (policy_version) do nothing;

create table if not exists public.ai_cost_anomaly_alerts (
  id uuid primary key default gen_random_uuid(),
  observation_day date not null,
  operation text not null check (operation in (
    'arc_consultation', 'quest_planning', 'basic_mission_planning',
    'mission_redesign', 'detailed_progress_review'
  )),
  provider text not null check (provider in ('gemini', 'openai')),
  model_name text not null check (char_length(model_name) between 1 and 120),
  thinking_level text not null check (
    thinking_level in ('unknown', 'minimal', 'low', 'medium', 'high')
  ),
  used_grounding boolean not null,
  policy_version text not null references public.ai_cost_anomaly_policies(
    policy_version
  ) on delete restrict,
  observed_settled_calls bigint not null check (observed_settled_calls > 0),
  observed_cost_micros bigint not null check (observed_cost_micros >= 0),
  baseline_history_days integer not null check (baseline_history_days >= 0),
  baseline_average_cost_micros bigint not null check (
    baseline_average_cost_micros >= 0
  ),
  increase_ratio numeric(12, 4) not null check (increase_ratio >= 0),
  status text not null default 'open' check (
    status in ('open', 'confirmed', 'false_positive', 'recovered')
  ),
  resolution_reason text check (
    resolution_reason is null or resolution_reason in (
      'expected_volume_change', 'pricing_change', 'test_traffic',
      'provider_retry_spike', 'confirmed_cost_spike',
      'operation_contained', 'operation_recovered'
    )
  ),
  detected_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (
    observation_day,
    operation,
    provider,
    model_name,
    thinking_level,
    used_grounding,
    policy_version
  ),
  check (
    (status = 'open' and resolution_reason is null and resolved_at is null)
    or (
      status <> 'open'
      and resolution_reason is not null
      and resolved_at is not null
    )
  )
);

create index if not exists ai_cost_anomaly_alerts_status_day_idx
  on public.ai_cost_anomaly_alerts (status, observation_day desc);

create table if not exists public.ai_operation_control_audit (
  id uuid primary key default gen_random_uuid(),
  operation text not null check (operation in (
    'arc_consultation', 'quest_planning', 'basic_mission_planning',
    'mission_redesign', 'detailed_progress_review'
  )),
  previous_enabled boolean not null,
  current_enabled boolean not null,
  reason_code text not null check (reason_code in (
    'cost_anomaly_confirmed', 'incident_containment',
    'false_positive_recovery', 'operator_recovery'
  )),
  anomaly_alert_id uuid references public.ai_cost_anomaly_alerts(id)
    on delete set null,
  actor_kind text not null default 'service_operator' check (
    actor_kind = 'service_operator'
  ),
  created_at timestamptz not null default now(),
  check (previous_enabled is distinct from current_enabled)
);

alter table public.ai_cost_anomaly_policies enable row level security;
alter table public.ai_cost_anomaly_alerts enable row level security;
alter table public.ai_operation_control_audit enable row level security;

revoke all on public.ai_cost_anomaly_policies from public, anon, authenticated;
revoke all on public.ai_cost_anomaly_alerts from public, anon, authenticated;
revoke all on public.ai_operation_control_audit from public, anon, authenticated;

create or replace function public.record_ai_provider_execution_receipt_v3(
  p_reservation_id uuid,
  p_provider_interaction_id text,
  p_model_name text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_finish_reason text,
  p_trace_id uuid,
  p_grounding_query_count integer,
  p_thinking_level text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reservation public.ai_budget_reservations%rowtype;
  v_existing public.ai_provider_execution_receipts%rowtype;
  v_result jsonb;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_thinking_level not in ('minimal', 'low', 'medium', 'high') then
    raise exception 'invalid_provider_thinking_level';
  end if;

  select * into v_reservation
  from public.ai_budget_reservations
  where id = p_reservation_id
  for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;

  select * into v_existing
  from public.ai_provider_execution_receipts
  where reservation_id = p_reservation_id
  for update;
  if found
    and v_existing.thinking_level <> 'unknown'
    and v_existing.thinking_level <> p_thinking_level then
    insert into public.ai_budget_reconciliation_cases (
      reservation_id, user_id, trace_id, reason
    ) values (
      p_reservation_id,
      v_reservation.user_id,
      p_trace_id,
      'execution_evidence_conflict'
    ) on conflict (reservation_id) do update set
      status = 'open',
      reason = excluded.reason,
      resolved_at = null;
    insert into public.ai_budget_reconciliation_attempts (
      reservation_id, trace_id, evidence_digest, outcome, reason
    ) values (
      p_reservation_id,
      p_trace_id,
      v_existing.evidence_digest,
      'evidence_conflict',
      'provider_thinking_level_conflict'
    );
    return jsonb_build_object(
      'recorded', false,
      'reason', 'provider_thinking_level_conflict',
      'operator_review', true
    );
  end if;

  v_result := public.record_ai_provider_execution_receipt_v2(
    p_reservation_id,
    p_provider_interaction_id,
    p_model_name,
    p_input_tokens,
    p_output_tokens,
    p_finish_reason,
    p_trace_id,
    p_grounding_query_count
  );
  if coalesce((v_result ->> 'recorded')::boolean, false) is false then
    return v_result;
  end if;

  update public.ai_provider_execution_receipts
  set thinking_level = p_thinking_level
  where reservation_id = p_reservation_id
    and thinking_level in ('unknown', p_thinking_level);
  if not found then
    raise exception 'provider_thinking_level_conflict';
  end if;

  return v_result || jsonb_build_object('thinking_level', p_thinking_level);
end;
$$;

create or replace function public.require_ai_receipt_thinking_evidence()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_thinking_level text;
begin
  if old.status = 'reserved' and new.status = 'settled' then
    select thinking_level into v_thinking_level
    from public.ai_provider_execution_receipts
    where reservation_id = new.id;
    if not found or v_thinking_level = 'unknown' then
      raise exception 'ai_provider_thinking_evidence_required';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists require_ai_receipt_thinking_evidence
  on public.ai_budget_reservations;
create trigger require_ai_receipt_thinking_evidence
before update of status on public.ai_budget_reservations
for each row execute function public.require_ai_receipt_thinking_evidence();

create or replace view public.ai_cost_observations_daily
with (security_invoker = true)
as
select
  base.settled_at::date as usage_day,
  base.operation,
  base.provider,
  base.model_name,
  receipt.thinking_level,
  coalesce(grounding.actual_query_count, 0) > 0 as used_grounding,
  count(*) as settled_calls,
  coalesce(sum(base.actual_input_tokens), 0) as input_tokens,
  coalesce(sum(base.actual_output_tokens), 0) as output_tokens,
  coalesce(sum(base.actual_cost_micros), 0) as token_cost_micros,
  coalesce(sum(grounding.actual_cost_micros), 0) as grounding_cost_micros,
  coalesce(sum(base.actual_cost_micros), 0)
    + coalesce(sum(grounding.actual_cost_micros), 0) as total_cost_micros
from public.ai_budget_reservations base
join public.ai_provider_execution_receipts receipt
  on receipt.reservation_id = base.id
left join public.ai_grounding_budget_reservations grounding
  on grounding.reservation_id = base.id
  and grounding.status = 'settled'
where base.status = 'settled'
group by
  base.settled_at::date,
  base.operation,
  base.provider,
  base.model_name,
  receipt.thinking_level,
  coalesce(grounding.actual_query_count, 0) > 0;

revoke all on public.ai_cost_observations_daily
  from public, anon, authenticated;
grant select on public.ai_cost_observations_daily to service_role;

create or replace function public.detect_ai_cost_anomalies(
  p_observation_day date
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_policy public.ai_cost_anomaly_policies%rowtype;
  v_observation record;
  v_history_days integer;
  v_baseline numeric;
  v_ratio numeric;
  v_observed_groups integer := 0;
  v_created integer := 0;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_observation_day is null
    or p_observation_day > current_date
    or p_observation_day < current_date - 90 then
    raise exception 'invalid_ai_cost_observation_day';
  end if;

  select * into v_policy
  from public.ai_cost_anomaly_policies
  where active
  limit 1;
  if not found then
    return jsonb_build_object('evaluated', false, 'reason', 'policy_unavailable');
  end if;

  for v_observation in
    select *
    from public.ai_cost_observations_daily
    where usage_day = p_observation_day
      and settled_calls >= v_policy.minimum_settled_calls
  loop
    v_observed_groups := v_observed_groups + 1;
    select count(*), avg(history.total_cost_micros)
      into v_history_days, v_baseline
    from public.ai_cost_observations_daily history
    where history.usage_day >= p_observation_day - v_policy.baseline_days
      and history.usage_day < p_observation_day
      and history.operation = v_observation.operation
      and history.provider = v_observation.provider
      and history.model_name = v_observation.model_name
      and history.thinking_level = v_observation.thinking_level
      and history.used_grounding = v_observation.used_grounding
      and history.settled_calls >= v_policy.minimum_settled_calls;

    if v_history_days < v_policy.minimum_history_days
      or coalesce(v_baseline, 0) <= 0 then
      continue;
    end if;
    v_ratio := v_observation.total_cost_micros::numeric / v_baseline;
    if v_ratio < v_policy.increase_multiplier
      or v_observation.total_cost_micros - ceil(v_baseline)::bigint
        < v_policy.minimum_cost_delta_micros then
      continue;
    end if;

    insert into public.ai_cost_anomaly_alerts (
      observation_day,
      operation,
      provider,
      model_name,
      thinking_level,
      used_grounding,
      policy_version,
      observed_settled_calls,
      observed_cost_micros,
      baseline_history_days,
      baseline_average_cost_micros,
      increase_ratio
    ) values (
      p_observation_day,
      v_observation.operation,
      v_observation.provider,
      v_observation.model_name,
      v_observation.thinking_level,
      v_observation.used_grounding,
      v_policy.policy_version,
      v_observation.settled_calls,
      v_observation.total_cost_micros,
      v_history_days,
      ceil(v_baseline)::bigint,
      round(v_ratio, 4)
    ) on conflict do nothing;
    if found then v_created := v_created + 1; end if;
  end loop;

  return jsonb_build_object(
    'evaluated', true,
    'observation_day', p_observation_day,
    'policy_version', v_policy.policy_version,
    'observed_groups', v_observed_groups,
    'alerts_created', v_created
  );
end;
$$;

create or replace function public.resolve_ai_cost_anomaly(
  p_alert_id uuid,
  p_resolution text,
  p_reason_code text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_alert public.ai_cost_anomaly_alerts%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_resolution not in ('confirmed', 'false_positive', 'recovered') then
    raise exception 'invalid_ai_cost_anomaly_resolution';
  end if;
  if p_reason_code not in (
    'expected_volume_change', 'pricing_change', 'test_traffic',
    'provider_retry_spike', 'confirmed_cost_spike',
    'operation_contained', 'operation_recovered'
  ) then
    raise exception 'invalid_ai_cost_anomaly_reason';
  end if;

  select * into v_alert
  from public.ai_cost_anomaly_alerts
  where id = p_alert_id
  for update;
  if not found then raise exception 'ai_cost_anomaly_not_found'; end if;
  if v_alert.status = p_resolution and v_alert.resolution_reason = p_reason_code then
    return jsonb_build_object('resolved', true, 'idempotent', true);
  end if;
  if v_alert.status <> 'open'
    and not (v_alert.status = 'confirmed' and p_resolution = 'recovered') then
    raise exception 'ai_cost_anomaly_not_resolvable';
  end if;

  update public.ai_cost_anomaly_alerts
  set status = p_resolution,
      resolution_reason = p_reason_code,
      resolved_at = now()
  where id = p_alert_id;
  return jsonb_build_object('resolved', true, 'idempotent', false);
end;
$$;

create or replace function public.set_ai_operation_control(
  p_operation text,
  p_enabled boolean,
  p_reason_code text,
  p_anomaly_alert_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_control public.ai_operation_controls%rowtype;
  v_alert public.ai_cost_anomaly_alerts%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_reason_code not in (
    'cost_anomaly_confirmed', 'incident_containment',
    'false_positive_recovery', 'operator_recovery'
  ) then
    raise exception 'invalid_ai_operation_control_reason';
  end if;

  select * into v_control
  from public.ai_operation_controls
  where operation = p_operation
  for update;
  if not found then raise exception 'ai_operation_control_not_found'; end if;

  if p_anomaly_alert_id is not null then
    select * into v_alert
    from public.ai_cost_anomaly_alerts
    where id = p_anomaly_alert_id
    for update;
    if not found or v_alert.operation <> p_operation then
      raise exception 'ai_cost_anomaly_operation_mismatch';
    end if;
  end if;

  if v_control.enabled = p_enabled then
    return jsonb_build_object('updated', true, 'idempotent', true);
  end if;

  update public.ai_operation_controls
  set enabled = p_enabled,
      disabled_reason = case
        when p_enabled then null
        else p_reason_code
      end,
      updated_at = now()
  where operation = p_operation;

  insert into public.ai_operation_control_audit (
    operation,
    previous_enabled,
    current_enabled,
    reason_code,
    anomaly_alert_id
  ) values (
    p_operation,
    v_control.enabled,
    p_enabled,
    p_reason_code,
    p_anomaly_alert_id
  );

  return jsonb_build_object(
    'updated', true,
    'idempotent', false,
    'operation', p_operation,
    'enabled', p_enabled
  );
end;
$$;

revoke all on function public.record_ai_provider_execution_receipt_v3(
  uuid, text, text, integer, integer, text, uuid, integer, text
) from public;
revoke all on function public.require_ai_receipt_thinking_evidence()
  from public;
revoke all on function public.detect_ai_cost_anomalies(date) from public;
revoke all on function public.resolve_ai_cost_anomaly(uuid, text, text)
  from public;
revoke all on function public.set_ai_operation_control(
  text, boolean, text, uuid
) from public;

grant execute on function public.record_ai_provider_execution_receipt_v3(
  uuid, text, text, integer, integer, text, uuid, integer, text
) to service_role;
grant execute on function public.detect_ai_cost_anomalies(date)
  to service_role;
grant execute on function public.resolve_ai_cost_anomaly(uuid, text, text)
  to service_role;
grant execute on function public.set_ai_operation_control(
  text, boolean, text, uuid
) to service_role;

commit;
