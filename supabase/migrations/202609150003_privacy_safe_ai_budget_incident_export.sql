begin;

create table if not exists public.ai_budget_incident_export_policies (
  policy_version text primary key check (
    policy_version ~ '^ai_budget_incident_export_[0-9]{8}_v[0-9]+$'
  ),
  active boolean not null default false,
  minimum_group_size integer not null check (
    minimum_group_size between 5 and 100
  ),
  maximum_period_days integer not null check (
    maximum_period_days between 1 and 90
  ),
  maximum_history_days integer not null check (
    maximum_history_days between 1 and 365
  ),
  default_retention interval not null check (
    default_retention between interval '1 hour' and interval '30 days'
  ),
  created_at timestamptz not null default now()
);

create unique index if not exists ai_budget_incident_export_one_active_policy_idx
  on public.ai_budget_incident_export_policies (active)
  where active;

insert into public.ai_budget_incident_export_policies (
  policy_version,
  active,
  minimum_group_size,
  maximum_period_days,
  maximum_history_days,
  default_retention
) values (
  'ai_budget_incident_export_20260915_v1',
  true,
  5,
  31,
  90,
  interval '7 days'
) on conflict (policy_version) do nothing;

create table if not exists public.ai_budget_incident_exports (
  id uuid primary key default gen_random_uuid(),
  generated_by_operator_id uuid not null references
    public.ai_budget_reconciliation_operators(id) on delete restrict,
  schema_version text not null check (
    schema_version = 'ai_budget_incident_export_v1'
  ),
  policy_version text not null references
    public.ai_budget_incident_export_policies(policy_version) on delete restrict,
  period_start date not null,
  period_end date not null,
  status text not null default 'ready' check (
    status in ('ready', 'expired', 'deleted')
  ),
  aggregate_payload jsonb,
  payload_digest text not null check (payload_digest ~ '^[0-9a-f]{64}$'),
  included_group_count integer not null check (included_group_count >= 0),
  suppressed_group_count integer not null check (suppressed_group_count >= 0),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  expired_at timestamptz,
  deleted_at timestamptz,
  check (period_start <= period_end),
  check (expires_at > created_at),
  check (
    (
      status = 'ready'
      and aggregate_payload is not null
      and expired_at is null
      and deleted_at is null
    ) or (
      status = 'expired'
      and aggregate_payload is null
      and expired_at is not null
      and deleted_at is null
    ) or (
      status = 'deleted'
      and aggregate_payload is null
      and deleted_at is not null
    )
  )
);

create index if not exists ai_budget_incident_exports_expiry_idx
  on public.ai_budget_incident_exports (status, expires_at)
  where status = 'ready';

create table if not exists public.ai_budget_incident_export_events (
  id uuid primary key default gen_random_uuid(),
  export_id uuid not null references public.ai_budget_incident_exports(id)
    on delete cascade,
  operator_id uuid references public.ai_budget_reconciliation_operators(id)
    on delete restrict,
  actor_kind text not null check (actor_kind in ('human', 'service_worker')),
  event_type text not null check (
    event_type in ('generated', 'accessed', 'expired', 'deleted')
  ),
  schema_version text not null check (
    schema_version = 'ai_budget_incident_export_v1'
  ),
  period_start date not null,
  period_end date not null,
  occurred_at timestamptz not null default now(),
  check (
    (actor_kind = 'human' and operator_id is not null)
    or (actor_kind = 'service_worker' and operator_id is null)
  )
);

create index if not exists ai_budget_incident_export_events_export_idx
  on public.ai_budget_incident_export_events (export_id, occurred_at desc);

alter table public.ai_budget_incident_export_policies enable row level security;
alter table public.ai_budget_incident_exports enable row level security;
alter table public.ai_budget_incident_export_events enable row level security;

revoke all on public.ai_budget_incident_export_policies
  from public, anon, authenticated;
revoke all on public.ai_budget_incident_exports
  from public, anon, authenticated;
revoke all on public.ai_budget_incident_export_events
  from public, anon, authenticated;

create or replace function public.enforce_ai_budget_incident_export_payload()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_policy public.ai_budget_incident_export_policies%rowtype;
  v_item jsonb;
begin
  if new.aggregate_payload is null then
    return new;
  end if;

  select * into v_policy
  from public.ai_budget_incident_export_policies policy
  where policy.policy_version = new.policy_version;
  if not found then
    raise exception 'ai_budget_incident_export_policy_missing';
  end if;

  if jsonb_typeof(new.aggregate_payload) <> 'object'
    or not (
      new.aggregate_payload ?& array[
        'schema_version', 'period', 'minimum_group_size',
        'aggregate_count', 'aggregates'
      ]
    )
    or (
      new.aggregate_payload - array[
        'schema_version', 'period', 'minimum_group_size',
        'aggregate_count', 'aggregates'
      ]
    ) <> '{}'::jsonb
    or new.aggregate_payload ->> 'schema_version' <> new.schema_version
    or jsonb_typeof(new.aggregate_payload -> 'period') <> 'object'
    or not (
      (new.aggregate_payload -> 'period') ?& array['start', 'end']
    )
    or ((new.aggregate_payload -> 'period') - array['start', 'end'])
      <> '{}'::jsonb
    or new.aggregate_payload #>> '{period,start}' <> new.period_start::text
    or new.aggregate_payload #>> '{period,end}' <> new.period_end::text
    or (new.aggregate_payload ->> 'minimum_group_size')::integer
      <> v_policy.minimum_group_size
    or (new.aggregate_payload ->> 'aggregate_count')::integer
      <> new.included_group_count
    or jsonb_typeof(new.aggregate_payload -> 'aggregates') <> 'array'
    or jsonb_array_length(new.aggregate_payload -> 'aggregates')
      <> new.included_group_count then
    raise exception 'invalid_ai_budget_incident_export_contract';
  end if;

  for v_item in
    select value from jsonb_array_elements(new.aggregate_payload -> 'aggregates')
  loop
    if jsonb_typeof(v_item) <> 'object'
      or not (
        v_item ?& array[
          'reason', 'count', 'latency_p95_ms', 'cost_micros'
        ]
      )
      or (v_item - array[
        'reason', 'count', 'latency_p95_ms', 'cost_micros'
      ]) <> '{}'::jsonb
      or jsonb_typeof(v_item -> 'reason') <> 'string'
      or (v_item ->> 'reason') !~ '^((usage:(settled|released|expired))|(reconciliation:(settled|already_settled|operator_review|status_conflict|evidence_conflict|settlement_failed))|(worker:(running|completed|retryable_failed):(timeout|rate_limited|database_unavailable|permission_denied|invalid_configuration|unknown|none))|(anomaly:(open|confirmed|false_positive|recovered):(expected_volume_change|pricing_change|test_traffic|provider_retry_spike|confirmed_cost_spike|operation_contained|operation_recovered|unresolved)))$'
      or jsonb_typeof(v_item -> 'count') <> 'number'
      or (v_item ->> 'count')::bigint < v_policy.minimum_group_size
      or (
        v_item -> 'latency_p95_ms' <> 'null'::jsonb
        and jsonb_typeof(v_item -> 'latency_p95_ms') <> 'number'
      )
      or jsonb_typeof(v_item -> 'cost_micros') <> 'number' then
      raise exception 'invalid_ai_budget_incident_export_aggregate';
    end if;
  end loop;

  if new.aggregate_payload::text ~* '"(prompt|response|quest|user_id|provider_interaction_id|trace_id|reservation_id)"[[:space:]]*:' then
    raise exception 'forbidden_ai_budget_incident_export_field';
  end if;
  return new;
exception
  when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'invalid_ai_budget_incident_export_contract';
end;
$$;

drop trigger if exists enforce_ai_budget_incident_export_payload
  on public.ai_budget_incident_exports;
create trigger enforce_ai_budget_incident_export_payload
before insert or update of aggregate_payload, included_group_count,
  policy_version, schema_version, period_start, period_end
on public.ai_budget_incident_exports
for each row execute function public.enforce_ai_budget_incident_export_payload();

create or replace function public.generate_my_ai_budget_incident_export(
  p_period_start date,
  p_period_end date,
  p_schema_version text default 'ai_budget_incident_export_v1'
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_operator_id uuid;
  v_policy public.ai_budget_incident_export_policies%rowtype;
  v_payload jsonb;
  v_aggregates jsonb;
  v_included integer := 0;
  v_suppressed integer := 0;
  v_export_id uuid;
  v_expires_at timestamptz;
begin
  v_operator_id := public.current_ai_reconciliation_operator('reviewer');
  if p_schema_version <> 'ai_budget_incident_export_v1' then
    raise exception 'unsupported_ai_budget_incident_export_schema';
  end if;

  select * into v_policy
  from public.ai_budget_incident_export_policies policy
  where policy.active
  limit 1;
  if not found then
    raise exception 'ai_budget_incident_export_policy_missing';
  end if;
  if p_period_start is null
    or p_period_end is null
    or p_period_start > p_period_end
    or p_period_end > current_date
    or p_period_end - p_period_start + 1 > v_policy.maximum_period_days
    or p_period_start < current_date - v_policy.maximum_history_days then
    raise exception 'invalid_ai_budget_incident_export_period';
  end if;

  with aggregate_rows as (
    select
      'usage:' || reservation.status as reason,
      count(*)::bigint as event_count,
      round((percentile_cont(0.95) within group (
        order by reservation.admission_latency_ms
      ))::numeric, 2) as latency_p95_ms,
      coalesce(sum(reservation.actual_cost_micros), 0)::bigint
        + coalesce(sum(grounding.actual_cost_micros), 0)::bigint
          as cost_micros
    from public.ai_budget_reservations reservation
    left join public.ai_grounding_budget_reservations grounding
      on grounding.reservation_id = reservation.id
      and grounding.status = 'settled'
    where reservation.reserved_at::date between p_period_start and p_period_end
      and reservation.status in ('settled', 'released', 'expired')
    group by reservation.status

    union all

    select
      'reconciliation:' || attempt.outcome as reason,
      count(*)::bigint as event_count,
      null::numeric as latency_p95_ms,
      0::bigint as cost_micros
    from public.ai_budget_reconciliation_attempts attempt
    where attempt.attempted_at::date between p_period_start and p_period_end
    group by attempt.outcome

    union all

    select
      'worker:' || run.status || ':' || coalesce(run.error_code, 'none')
        as reason,
      count(*)::bigint as event_count,
      round((percentile_cont(0.95) within group (
        order by extract(epoch from run.completed_at - run.started_at) * 1000
      ) filter (where run.completed_at is not null))::numeric, 2)
        as latency_p95_ms,
      0::bigint as cost_micros
    from public.ai_budget_reconciliation_worker_runs run
    where run.started_at::date between p_period_start and p_period_end
    group by run.status, run.error_code

    union all

    select
      'anomaly:' || alert.status || ':'
        || coalesce(alert.resolution_reason, 'unresolved') as reason,
      count(*)::bigint as event_count,
      null::numeric as latency_p95_ms,
      coalesce(sum(alert.observed_cost_micros), 0)::bigint as cost_micros
    from public.ai_cost_anomaly_alerts alert
    where alert.observation_day between p_period_start and p_period_end
    group by alert.status, alert.resolution_reason
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'reason', reason,
          'count', event_count,
          'latency_p95_ms', latency_p95_ms,
          'cost_micros', cost_micros
        ) order by reason
      ) filter (where event_count >= v_policy.minimum_group_size),
      '[]'::jsonb
    ),
    count(*) filter (
      where event_count >= v_policy.minimum_group_size
    )::integer,
    count(*) filter (
      where event_count < v_policy.minimum_group_size
    )::integer
  into v_aggregates, v_included, v_suppressed
  from aggregate_rows;

  v_payload := jsonb_build_object(
    'schema_version', p_schema_version,
    'period', jsonb_build_object(
      'start', p_period_start,
      'end', p_period_end
    ),
    'minimum_group_size', v_policy.minimum_group_size,
    'aggregate_count', v_included,
    'aggregates', v_aggregates
  );
  v_expires_at := now() + v_policy.default_retention;

  insert into public.ai_budget_incident_exports (
    generated_by_operator_id,
    schema_version,
    policy_version,
    period_start,
    period_end,
    aggregate_payload,
    payload_digest,
    included_group_count,
    suppressed_group_count,
    expires_at
  ) values (
    v_operator_id,
    p_schema_version,
    v_policy.policy_version,
    p_period_start,
    p_period_end,
    v_payload,
    encode(digest(v_payload::text, 'sha256'), 'hex'),
    v_included,
    v_suppressed,
    v_expires_at
  ) returning id into v_export_id;

  insert into public.ai_budget_incident_export_events (
    export_id,
    operator_id,
    actor_kind,
    event_type,
    schema_version,
    period_start,
    period_end
  ) values (
    v_export_id,
    v_operator_id,
    'human',
    'generated',
    p_schema_version,
    p_period_start,
    p_period_end
  );

  return jsonb_build_object(
    'export_id', v_export_id,
    'schema_version', p_schema_version,
    'period_start', p_period_start,
    'period_end', p_period_end,
    'included_group_count', v_included,
    'expires_at', v_expires_at
  );
end;
$$;

create or replace function public.get_my_ai_budget_incident_export(
  p_export_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_operator_id uuid;
  v_export public.ai_budget_incident_exports%rowtype;
begin
  v_operator_id := public.current_ai_reconciliation_operator('reviewer');
  select * into v_export
  from public.ai_budget_incident_exports export
  where export.id = p_export_id
  for update;
  if not found then
    raise exception 'ai_budget_incident_export_not_found';
  end if;
  if v_export.status <> 'ready' then
    raise exception 'ai_budget_incident_export_unavailable';
  end if;
  if v_export.expires_at <= now() then
    update public.ai_budget_incident_exports
    set status = 'expired',
        aggregate_payload = null,
        expired_at = now()
    where id = p_export_id;
    insert into public.ai_budget_incident_export_events (
      export_id, actor_kind, event_type, schema_version,
      period_start, period_end
    ) values (
      p_export_id, 'service_worker', 'expired', v_export.schema_version,
      v_export.period_start, v_export.period_end
    );
    return jsonb_build_object(
      'available', false,
      'reason', 'ai_budget_incident_export_expired'
    );
  end if;

  insert into public.ai_budget_incident_export_events (
    export_id,
    operator_id,
    actor_kind,
    event_type,
    schema_version,
    period_start,
    period_end
  ) values (
    p_export_id,
    v_operator_id,
    'human',
    'accessed',
    v_export.schema_version,
    v_export.period_start,
    v_export.period_end
  );
  return v_export.aggregate_payload;
end;
$$;

create or replace function public.delete_my_ai_budget_incident_export(
  p_export_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_operator_id uuid;
  v_operator_role text;
  v_export public.ai_budget_incident_exports%rowtype;
begin
  v_operator_id := public.current_ai_reconciliation_operator('reviewer');
  select operator.operator_role into v_operator_role
  from public.ai_budget_reconciliation_operators operator
  where operator.id = v_operator_id;

  select * into v_export
  from public.ai_budget_incident_exports export
  where export.id = p_export_id
  for update;
  if not found then
    raise exception 'ai_budget_incident_export_not_found';
  end if;
  if v_export.status = 'deleted' then
    return jsonb_build_object('deleted', true, 'idempotent', true);
  end if;
  if v_export.generated_by_operator_id <> v_operator_id
    and v_operator_role <> 'approver' then
    raise exception 'ai_budget_incident_export_delete_forbidden';
  end if;

  update public.ai_budget_incident_exports
  set status = 'deleted',
      aggregate_payload = null,
      deleted_at = now()
  where id = p_export_id;

  insert into public.ai_budget_incident_export_events (
    export_id,
    operator_id,
    actor_kind,
    event_type,
    schema_version,
    period_start,
    period_end
  ) values (
    p_export_id,
    v_operator_id,
    'human',
    'deleted',
    v_export.schema_version,
    v_export.period_start,
    v_export.period_end
  );
  return jsonb_build_object('deleted', true, 'idempotent', false);
end;
$$;

create or replace function public.expire_ai_budget_incident_exports()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_export record;
  v_expired integer := 0;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  for v_export in
    update public.ai_budget_incident_exports export
    set status = 'expired',
        aggregate_payload = null,
        expired_at = now()
    where export.status = 'ready'
      and export.expires_at <= now()
    returning export.id, export.schema_version,
      export.period_start, export.period_end
  loop
    insert into public.ai_budget_incident_export_events (
      export_id, actor_kind, event_type, schema_version,
      period_start, period_end
    ) values (
      v_export.id, 'service_worker', 'expired', v_export.schema_version,
      v_export.period_start, v_export.period_end
    );
    v_expired := v_expired + 1;
  end loop;
  return jsonb_build_object('expired_count', v_expired);
end;
$$;

revoke all on function public.enforce_ai_budget_incident_export_payload()
  from public;
revoke all on function public.generate_my_ai_budget_incident_export(
  date, date, text
) from public;
revoke all on function public.get_my_ai_budget_incident_export(uuid)
  from public;
revoke all on function public.delete_my_ai_budget_incident_export(uuid)
  from public;
revoke all on function public.expire_ai_budget_incident_exports()
  from public;

grant execute on function public.generate_my_ai_budget_incident_export(
  date, date, text
) to authenticated;
grant execute on function public.get_my_ai_budget_incident_export(uuid)
  to authenticated;
grant execute on function public.delete_my_ai_budget_incident_export(uuid)
  to authenticated;
grant execute on function public.expire_ai_budget_incident_exports()
  to service_role;

commit;
