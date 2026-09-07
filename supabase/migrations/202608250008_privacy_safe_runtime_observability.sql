begin;

create table if not exists public.runtime_evidence_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  event_id text not null,
  occurred_at timestamptz not null,
  build_version text not null,
  environment text not null check (environment in ('internal_beta', 'production')),
  platform text not null,
  surface text not null,
  operation text not null,
  event_type text not null check (event_type in (
    'appCrash', 'flutterFrameworkError', 'unhandledAsyncError',
    'persistenceFailure', 'authFailure', 'mediaFailure', 'aiFallback'
  )),
  severity text not null check (severity in ('S0', 'S1', 'S2', 'S3')),
  error_code text not null,
  correlation_id text not null,
  handled boolean not null,
  fallback_used boolean not null,
  retention_until timestamptz not null default (now() + interval '30 days'),
  created_at timestamptz not null default now(),
  unique(owner_id, event_id)
);

create index if not exists runtime_evidence_owner_created_idx
  on public.runtime_evidence_events(owner_id, created_at desc);
create index if not exists runtime_evidence_retention_idx
  on public.runtime_evidence_events(retention_until);
create index if not exists runtime_evidence_slo_idx
  on public.runtime_evidence_events(environment, severity, created_at desc);

alter table public.runtime_evidence_events enable row level security;
drop policy if exists runtime_evidence_owner_select on public.runtime_evidence_events;
create policy runtime_evidence_owner_select on public.runtime_evidence_events
  for select using (owner_id = auth.uid());
revoke all on public.runtime_evidence_events from anon, authenticated;
grant select on public.runtime_evidence_events to authenticated;

create table if not exists public.runtime_evidence_alert_queue (
  id uuid primary key default gen_random_uuid(),
  event_row_id uuid not null unique references public.runtime_evidence_events(id) on delete cascade,
  severity text not null check (severity in ('S0', 'S1')),
  state text not null default 'pending' check (state in ('pending', 'claimed', 'resolved')),
  resolution_code text,
  claimed_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.runtime_evidence_alert_queue enable row level security;
revoke all on public.runtime_evidence_alert_queue from anon, authenticated;

create table if not exists public.runtime_evidence_rate_buckets (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null default now(),
  event_count integer not null default 0,
  high_severity_count integer not null default 0
);

alter table public.runtime_evidence_rate_buckets enable row level security;
revoke all on public.runtime_evidence_rate_buckets from anon, authenticated;

create or replace function public.record_runtime_evidence(p_event jsonb)
returns uuid
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_row_id uuid;
  v_event_id text := p_event ->> 'event_id';
  v_occurred_at timestamptz;
  v_build_version text := p_event ->> 'build_version';
  v_environment text := p_event ->> 'environment';
  v_platform text := p_event ->> 'platform';
  v_surface text := p_event ->> 'surface';
  v_operation text := p_event ->> 'operation';
  v_event_type text := p_event ->> 'event_type';
  v_severity text := p_event ->> 'severity';
  v_error_code text := p_event ->> 'error_code';
  v_correlation_id text := p_event ->> 'correlation_id';
  v_allowed_keys text[] := array[
    'event_id', 'occurred_at', 'build_version', 'environment', 'platform',
    'surface', 'operation', 'event_type', 'severity', 'error_code',
    'correlation_id', 'handled', 'fallback_used'
  ];
  v_key text;
  v_event_count integer;
  v_high_severity_count integer;
begin
  if v_owner is null then raise exception 'Authentication required.'; end if;
  if p_event is null or jsonb_typeof(p_event) <> 'object' then
    raise exception 'Evidence object required.';
  end if;
  for v_key in select jsonb_object_keys(p_event) loop
    if not (v_key = any(v_allowed_keys)) then
      raise exception 'Unsupported evidence field.';
    end if;
  end loop;
  if array_length(v_allowed_keys, 1) <> (
    select count(*) from jsonb_object_keys(p_event)
  ) then
    raise exception 'Incomplete evidence contract.';
  end if;
  if v_event_id !~ '^[A-Za-z0-9._:-]{1,120}$'
     or v_build_version !~ '^[A-Za-z0-9._:-]{1,120}$'
     or v_platform !~ '^[A-Za-z0-9._:-]{1,120}$'
     or v_surface !~ '^[A-Za-z0-9._:-]{1,120}$'
     or v_operation !~ '^[A-Za-z0-9._:-]{1,120}$'
     or v_error_code !~ '^[A-Za-z0-9._:-]{1,120}$'
     or v_correlation_id !~ '^[A-Za-z0-9._:-]{1,120}$' then
    raise exception 'Evidence contains an unsafe token.';
  end if;
  if v_environment not in ('internal_beta', 'production') then
    raise exception 'Unsupported evidence environment.';
  end if;
  if v_event_type not in (
    'appCrash', 'flutterFrameworkError', 'unhandledAsyncError',
    'persistenceFailure', 'authFailure', 'mediaFailure', 'aiFallback'
  ) or v_severity not in ('S0', 'S1', 'S2', 'S3') then
    raise exception 'Unsupported evidence classification.';
  end if;
  begin
    v_occurred_at := (p_event ->> 'occurred_at')::timestamptz;
  exception when others then
    raise exception 'Invalid evidence timestamp.';
  end;
  if v_occurred_at < now() - interval '24 hours'
     or v_occurred_at > now() + interval '5 minutes' then
    raise exception 'Evidence timestamp is outside the accepted window.';
  end if;

  insert into public.runtime_evidence_rate_buckets(
    owner_id, window_started_at, event_count, high_severity_count
  ) values (
    v_owner, now(), 1, case when v_severity in ('S0', 'S1') then 1 else 0 end
  ) on conflict (owner_id) do update set
    window_started_at = case
      when public.runtime_evidence_rate_buckets.window_started_at <= now() - interval '10 minutes'
        then now()
      else public.runtime_evidence_rate_buckets.window_started_at
    end,
    event_count = case
      when public.runtime_evidence_rate_buckets.window_started_at <= now() - interval '10 minutes'
        then 1
      else public.runtime_evidence_rate_buckets.event_count + 1
    end,
    high_severity_count = case
      when public.runtime_evidence_rate_buckets.window_started_at <= now() - interval '10 minutes'
        then case when v_severity in ('S0', 'S1') then 1 else 0 end
      else public.runtime_evidence_rate_buckets.high_severity_count +
        case when v_severity in ('S0', 'S1') then 1 else 0 end
    end
  returning event_count, high_severity_count
    into v_event_count, v_high_severity_count;
  if v_event_count > 120 or v_high_severity_count > 10 then
    raise exception 'Runtime evidence rate limit exceeded.';
  end if;

  insert into public.runtime_evidence_events(
    owner_id, event_id, occurred_at, build_version, environment, platform,
    surface, operation, event_type, severity, error_code, correlation_id,
    handled, fallback_used
  ) values (
    v_owner, v_event_id, v_occurred_at, v_build_version, v_environment,
    v_platform, v_surface, v_operation, v_event_type, v_severity,
    v_error_code, v_correlation_id,
    (p_event ->> 'handled')::boolean,
    (p_event ->> 'fallback_used')::boolean
  ) on conflict (owner_id, event_id) do update set event_id = excluded.event_id
  returning id into v_row_id;

  if v_severity in ('S0', 'S1') then
    insert into public.runtime_evidence_alert_queue(event_row_id, severity)
    values (v_row_id, v_severity)
    on conflict (event_row_id) do nothing;
  end if;
  return v_row_id;
end;
$$;

create or replace function public.claim_runtime_evidence_alerts(
  p_limit integer default 20
) returns table(alert_id uuid, severity text, build_version text, surface text, operation text, error_code text)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Alert operator authorization required.';
  end if;
  return query
  with candidates as (
    select queue.id from public.runtime_evidence_alert_queue queue
    where queue.state = 'pending'
    order by queue.created_at
    for update skip locked
    limit least(greatest(p_limit, 1), 100)
  ), claimed as (
    update public.runtime_evidence_alert_queue queue
    set state = 'claimed', claimed_at = now()
    from candidates where queue.id = candidates.id
    returning queue.id, queue.event_row_id, queue.severity
  )
  select claimed.id, claimed.severity, event.build_version, event.surface,
    event.operation, event.error_code
  from claimed join public.runtime_evidence_events event
    on event.id = claimed.event_row_id;
end;
$$;

create or replace function public.resolve_runtime_evidence_alert(
  p_alert_id uuid, p_resolution_code text
) returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Alert operator authorization required.';
  end if;
  if p_resolution_code not in (
    'distribution_stopped', 'rollout_paused', 'false_positive', 'forward_fix_deployed'
  ) then
    raise exception 'Unsupported alert resolution.';
  end if;
  update public.runtime_evidence_alert_queue
  set state = 'resolved', resolution_code = p_resolution_code,
      resolved_at = now()
  where id = p_alert_id and state = 'claimed';
  if not found then raise exception 'Alert is not claimed.'; end if;
end;
$$;

create or replace function public.get_runtime_slo_window(
  p_since timestamptz default (now() - interval '1 hour')
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'SLO operator authorization required.';
  end if;
  if p_since < now() - interval '30 days' or p_since > now() then
    raise exception 'Unsupported SLO window.';
  end if;
  return (
    select jsonb_build_object(
      'total_events', count(*),
      's0_events', count(*) filter (where severity = 'S0'),
      's1_events', count(*) filter (where severity = 'S1'),
      'handled_events', count(*) filter (where handled),
      'fallback_events', count(*) filter (where fallback_used)
    ) from public.runtime_evidence_events where created_at >= p_since
  );
end;
$$;

create or replace function public.purge_expired_runtime_evidence(p_limit integer default 1000)
returns integer
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_deleted integer;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Retention worker authorization required.';
  end if;
  with expired as (
    select id from public.runtime_evidence_events
    where retention_until <= now()
    order by retention_until
    limit least(greatest(p_limit, 1), 10000)
  )
  delete from public.runtime_evidence_events event
  using expired where event.id = expired.id;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.record_runtime_evidence(jsonb) from public;
revoke all on function public.claim_runtime_evidence_alerts(integer) from public;
revoke all on function public.resolve_runtime_evidence_alert(uuid, text) from public;
revoke all on function public.get_runtime_slo_window(timestamptz) from public;
revoke all on function public.purge_expired_runtime_evidence(integer) from public;
grant execute on function public.record_runtime_evidence(jsonb) to authenticated;
grant execute on function public.claim_runtime_evidence_alerts(integer) to service_role;
grant execute on function public.resolve_runtime_evidence_alert(uuid, text) to service_role;
grant execute on function public.get_runtime_slo_window(timestamptz) to service_role;
grant execute on function public.purge_expired_runtime_evidence(integer) to service_role;

commit;
