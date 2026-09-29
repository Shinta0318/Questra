begin;

alter table public.ai_budget_reconciliation_operator_events
  drop constraint if exists ai_budget_reconciliation_operator_events_action_check,
  drop constraint if exists ai_budget_reconciliation_operator_events_reason_code_check;

alter table public.ai_budget_reconciliation_operator_events
  add constraint ai_budget_reconciliation_operator_event_action_check check (
    action in (
      'claimed', 'claim_released', 'lease_recovered', 'resolved', 'dismissed',
      'correction_requested', 'correction_approved',
      'correction_rejected', 'correction_applied'
    )
  ),
  add constraint ai_budget_reconciliation_operator_event_reason_check check (
    reason_code in (
      'oldest_open_first', 'expired_claim_reclaimed',
      'expired_claim_recovered', 'operator_released',
      'evidence_verified_no_change', 'reservation_released_no_execution',
      'duplicate_execution_no_change', 'false_positive',
      'correction_applied', 'evidence_unavailable',
      'provider_usage_correction', 'provider_refund', 'duplicate_charge',
      'manual_audit', 'evidence_verified', 'insufficient_evidence'
    )
  );

insert into public.ai_budget_reconciliation_operators (
  operator_key,
  operator_role,
  enabled,
  disabled_at,
  actor_kind
) values (
  'ai-budget-reconciliation-scheduler',
  'reviewer',
  false,
  now(),
  'service_worker'
) on conflict (operator_key) do nothing;

create table if not exists public.ai_budget_reconciliation_worker_control (
  id text primary key check (id = 'scheduler'),
  enabled boolean not null default false,
  stale_after interval not null default interval '15 minutes' check (
    stale_after between interval '10 minutes' and interval '30 days'
  ),
  batch_limit integer not null default 100 check (batch_limit between 1 and 500),
  claim_recovery_limit integer not null default 100 check (
    claim_recovery_limit between 1 and 500
  ),
  sla interval not null default interval '24 hours' check (
    sla between interval '15 minutes' and interval '30 days'
  ),
  alert_cooldown interval not null default interval '1 hour' check (
    alert_cooldown between interval '5 minutes' and interval '24 hours'
  ),
  updated_at timestamptz not null default now()
);

insert into public.ai_budget_reconciliation_worker_control (id)
values ('scheduler')
on conflict (id) do nothing;

create table if not exists public.ai_budget_reconciliation_worker_runs (
  id uuid primary key default gen_random_uuid(),
  schedule_key_digest text not null unique check (
    schedule_key_digest ~ '^[0-9a-f]{64}$'
  ),
  status text not null check (
    status in ('running', 'completed', 'retryable_failed')
  ),
  attempt_count integer not null default 1 check (attempt_count between 1 and 20),
  processed_count integer not null default 0 check (processed_count >= 0),
  reconciled_count integer not null default 0 check (reconciled_count >= 0),
  operator_review_count integer not null default 0 check (
    operator_review_count >= 0
  ),
  recovered_claim_count integer not null default 0 check (
    recovered_claim_count >= 0
  ),
  sla_alert_created boolean not null default false,
  error_code text check (
    error_code is null or error_code in (
      'timeout', 'rate_limited', 'database_unavailable',
      'permission_denied', 'invalid_configuration', 'unknown'
    )
  ),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  retry_after timestamptz,
  retention_until timestamptz not null default (now() + interval '90 days'),
  check (
    (status = 'completed' and completed_at is not null and error_code is null)
    or (
      status = 'running'
      and completed_at is null
      and error_code is null
      and retry_after is null
    )
    or (
      status = 'retryable_failed'
      and completed_at is null
      and error_code is not null
      and retry_after is not null
    )
  )
);

create table if not exists public.ai_budget_reconciliation_sla_alerts (
  id uuid primary key default gen_random_uuid(),
  dedupe_key text not null unique check (dedupe_key ~ '^[0-9a-f]{64}$'),
  alert_kind text not null check (
    alert_kind in ('queue_sla_breach', 'worker_failure')
  ),
  severity text not null check (severity in ('s1', 's2')),
  open_count integer not null default 0 check (open_count >= 0),
  sla_breached_count integer not null default 0 check (
    sla_breached_count >= 0
  ),
  oldest_age_bucket text not null check (
    oldest_age_bucket in (
      'under_24_hours', 'one_to_three_days', 'over_three_days', 'unknown'
    )
  ),
  state text not null default 'pending' check (
    state in ('pending', 'claimed', 'retryable_failed', 'delivered')
  ),
  delivery_attempts integer not null default 0 check (
    delivery_attempts between 0 and 20
  ),
  available_at timestamptz not null default now(),
  claimed_at timestamptz,
  claim_expires_at timestamptz,
  delivered_at timestamptz,
  delivery_error_code text check (
    delivery_error_code is null or delivery_error_code in (
      'timeout', 'http_error', 'invalid_endpoint', 'unavailable', 'unknown'
    )
  ),
  created_at timestamptz not null default now(),
  retention_until timestamptz not null default (now() + interval '90 days'),
  check (
    (
      state = 'pending'
      and claimed_at is null
      and claim_expires_at is null
      and delivered_at is null
    )
    or (
      state = 'claimed'
      and claimed_at is not null
      and claim_expires_at is not null
      and delivered_at is null
    )
    or (
      state = 'retryable_failed'
      and claimed_at is null
      and claim_expires_at is null
      and delivered_at is null
      and delivery_error_code is not null
    )
    or (
      state = 'delivered'
      and claimed_at is not null
      and claim_expires_at is not null
      and delivered_at is not null
      and delivery_error_code is null
    )
  )
);

create index if not exists ai_budget_reconciliation_alert_delivery_idx
  on public.ai_budget_reconciliation_sla_alerts (
    state, available_at, claim_expires_at, created_at
  )
  where state in ('pending', 'retryable_failed', 'claimed');

create index if not exists ai_budget_reconciliation_worker_run_retention_idx
  on public.ai_budget_reconciliation_worker_runs (retention_until);

create index if not exists ai_budget_reconciliation_alert_retention_idx
  on public.ai_budget_reconciliation_sla_alerts (retention_until);

alter table public.ai_budget_reconciliation_worker_control enable row level security;
alter table public.ai_budget_reconciliation_worker_runs enable row level security;
alter table public.ai_budget_reconciliation_sla_alerts enable row level security;

revoke all on public.ai_budget_reconciliation_worker_control
  from public, anon, authenticated;
revoke all on public.ai_budget_reconciliation_worker_runs
  from public, anon, authenticated;
revoke all on public.ai_budget_reconciliation_sla_alerts
  from public, anon, authenticated;

create or replace function public.ai_reconciliation_age_bucket(
  p_age_seconds bigint
) returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
    when p_age_seconds < 0 then 'unknown'
    when p_age_seconds < 86400 then 'under_24_hours'
    when p_age_seconds < 259200 then 'one_to_three_days'
    else 'over_three_days'
  end;
$$;

create or replace function public.run_ai_budget_reconciliation_scheduler(
  p_schedule_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_control public.ai_budget_reconciliation_worker_control%rowtype;
  v_run public.ai_budget_reconciliation_worker_runs%rowtype;
  v_worker_id uuid;
  v_schedule_digest text;
  v_classification jsonb;
  v_inserted integer := 0;
  v_recovered integer := 0;
  v_open integer := 0;
  v_breached integer := 0;
  v_pending_alerts integer := 0;
  v_oldest_age bigint := 0;
  v_window bigint;
  v_alert_created boolean := false;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_schedule_key is null
    or char_length(p_schedule_key) not between 8 and 100
    or p_schedule_key !~ '^[A-Za-z0-9:_.-]+$' then
    raise exception 'invalid_reconciliation_schedule_key';
  end if;

  select * into v_control
  from public.ai_budget_reconciliation_worker_control control
  where control.id = 'scheduler'
  for update;
  if not found then
    raise exception 'reconciliation_worker_configuration_missing';
  end if;
  if not v_control.enabled then
    return jsonb_build_object(
      'executed', false,
      'disabled', true,
      'idempotent', false
    );
  end if;

  select operator.id into v_worker_id
  from public.ai_budget_reconciliation_operators operator
  where operator.operator_key = 'ai-budget-reconciliation-scheduler'
    and operator.actor_kind = 'service_worker'
    and operator.operator_role = 'reviewer'
    and operator.enabled;
  if not found then
    raise exception 'reconciliation_worker_identity_required';
  end if;

  v_schedule_digest := encode(digest(p_schedule_key, 'sha256'), 'hex');
  insert into public.ai_budget_reconciliation_worker_runs (
    schedule_key_digest,
    status
  ) values (
    v_schedule_digest,
    'running'
  ) on conflict (schedule_key_digest) do nothing;
  get diagnostics v_inserted = row_count;

  select * into v_run
  from public.ai_budget_reconciliation_worker_runs run
  where run.schedule_key_digest = v_schedule_digest
  for update;

  if v_inserted = 0 and v_run.status = 'completed' then
    select count(*) into v_pending_alerts
    from public.ai_budget_reconciliation_sla_alerts alert
    where alert.state in ('pending', 'retryable_failed');
    return jsonb_build_object(
      'executed', false,
      'disabled', false,
      'idempotent', true,
      'processed_count', v_run.processed_count,
      'reconciled_count', v_run.reconciled_count,
      'operator_review_count', v_run.operator_review_count,
      'recovered_claim_count', v_run.recovered_claim_count,
      'sla_alert_created', v_run.sla_alert_created,
      'pending_alert_count', v_pending_alerts
    );
  end if;

  if v_inserted = 0
    and v_run.status = 'retryable_failed'
    and v_run.retry_after > now() then
    return jsonb_build_object(
      'executed', false,
      'disabled', false,
      'idempotent', true,
      'retry_scheduled', true,
      'retry_after_seconds', greatest(
        ceil(extract(epoch from v_run.retry_after - now()))::integer,
        1
      )
    );
  end if;

  if v_inserted = 0 then
    if v_run.attempt_count >= 20 then
      raise exception 'reconciliation_worker_retry_limit_reached';
    end if;
    update public.ai_budget_reconciliation_worker_runs
    set status = 'running',
        attempt_count = attempt_count + 1,
        error_code = null,
        started_at = now(),
        completed_at = null,
        retry_after = null
    where id = v_run.id;
  end if;

  v_classification := public.classify_stale_ai_budget_reservations(
    v_control.stale_after,
    v_control.batch_limit
  );

  with expired as (
    select review.reservation_id
    from public.ai_budget_reconciliation_cases review
    where review.status = 'open'
      and review.claimed_by is not null
      and review.claim_expires_at <= now()
    order by review.claim_expires_at, review.reservation_id
    for update skip locked
    limit v_control.claim_recovery_limit
  ), recovered as (
    update public.ai_budget_reconciliation_cases review
    set claimed_by = null,
        claimed_at = null,
        claim_expires_at = null,
        updated_at = now()
    from expired
    where review.reservation_id = expired.reservation_id
    returning review.reservation_id
  ), audited as (
    insert into public.ai_budget_reconciliation_operator_events (
      reservation_id,
      operator_id,
      action,
      reason_code
    )
    select recovered.reservation_id,
           v_worker_id,
           'lease_recovered',
           'expired_claim_recovered'
    from recovered
    returning id
  )
  select count(*) into v_recovered from audited;

  select count(*) into v_open
  from public.ai_budget_reconciliation_cases review
  where review.status = 'open';
  select count(*) into v_breached
  from public.ai_budget_reconciliation_cases review
  where review.status = 'open'
    and review.opened_at <= now() - v_control.sla;
  select coalesce(
    floor(extract(epoch from now() - min(review.opened_at)))::bigint,
    0
  ) into v_oldest_age
  from public.ai_budget_reconciliation_cases review
  where review.status = 'open';

  if v_breached > 0 then
    v_window := floor(
      extract(epoch from now()) / extract(epoch from v_control.alert_cooldown)
    )::bigint;
    insert into public.ai_budget_reconciliation_sla_alerts (
      dedupe_key,
      alert_kind,
      severity,
      open_count,
      sla_breached_count,
      oldest_age_bucket
    ) values (
      encode(digest('queue_sla_breach:' || v_window::text, 'sha256'), 'hex'),
      'queue_sla_breach',
      case when v_oldest_age >= 259200 then 's1' else 's2' end,
      v_open,
      v_breached,
      public.ai_reconciliation_age_bucket(v_oldest_age)
    ) on conflict (dedupe_key) do nothing;
    get diagnostics v_inserted = row_count;
    v_alert_created := v_inserted > 0;
  end if;

  select count(*) into v_pending_alerts
  from public.ai_budget_reconciliation_sla_alerts alert
  where alert.state in ('pending', 'retryable_failed');

  update public.ai_budget_reconciliation_worker_runs
  set status = 'completed',
      processed_count = coalesce((v_classification ->> 'processed')::integer, 0),
      reconciled_count = coalesce((v_classification ->> 'reconciled')::integer, 0),
      operator_review_count = coalesce(
        (v_classification ->> 'operator_review')::integer,
        0
      ),
      recovered_claim_count = v_recovered,
      sla_alert_created = v_alert_created,
      completed_at = now(),
      error_code = null,
      retry_after = null
  where schedule_key_digest = v_schedule_digest;

  return jsonb_build_object(
    'executed', true,
    'disabled', false,
    'idempotent', false,
    'processed_count', coalesce((v_classification ->> 'processed')::integer, 0),
    'reconciled_count', coalesce((v_classification ->> 'reconciled')::integer, 0),
    'operator_review_count', coalesce(
      (v_classification ->> 'operator_review')::integer,
      0
    ),
    'recovered_claim_count', v_recovered,
    'open_count', v_open,
    'sla_breached_count', v_breached,
    'sla_alert_created', v_alert_created,
    'pending_alert_count', v_pending_alerts
  );
end;
$$;

create or replace function public.record_ai_budget_reconciliation_worker_failure(
  p_schedule_key text,
  p_error_code text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_control public.ai_budget_reconciliation_worker_control%rowtype;
  v_schedule_digest text;
  v_window bigint;
  v_recorded integer := 0;
  v_pending integer := 0;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_schedule_key is null
    or char_length(p_schedule_key) not between 8 and 100
    or p_schedule_key !~ '^[A-Za-z0-9:_.-]+$' then
    raise exception 'invalid_reconciliation_schedule_key';
  end if;
  if p_error_code not in (
    'timeout', 'rate_limited', 'database_unavailable',
    'permission_denied', 'invalid_configuration', 'unknown'
  ) then
    raise exception 'invalid_reconciliation_worker_error';
  end if;

  select * into v_control
  from public.ai_budget_reconciliation_worker_control control
  where control.id = 'scheduler';
  if not found then
    raise exception 'reconciliation_worker_configuration_missing';
  end if;

  v_schedule_digest := encode(digest(p_schedule_key, 'sha256'), 'hex');
  insert into public.ai_budget_reconciliation_worker_runs (
    schedule_key_digest,
    status,
    error_code,
    retry_after
  ) values (
    v_schedule_digest,
    'retryable_failed',
    p_error_code,
    now() + interval '5 minutes'
  ) on conflict (schedule_key_digest) do update set
    status = 'retryable_failed',
    error_code = excluded.error_code,
    completed_at = null,
    retry_after = excluded.retry_after
  where public.ai_budget_reconciliation_worker_runs.status <> 'completed';
  get diagnostics v_recorded = row_count;

  if v_recorded > 0 then
    v_window := floor(
      extract(epoch from now()) / extract(epoch from v_control.alert_cooldown)
    )::bigint;
    insert into public.ai_budget_reconciliation_sla_alerts (
      dedupe_key,
      alert_kind,
      severity,
      oldest_age_bucket
    ) values (
      encode(digest(
        'worker_failure:' || p_error_code || ':' || v_window::text,
        'sha256'
      ), 'hex'),
      'worker_failure',
      's1',
      'unknown'
    ) on conflict (dedupe_key) do nothing;
  end if;

  select count(*) into v_pending
  from public.ai_budget_reconciliation_sla_alerts alert
  where alert.state in ('pending', 'retryable_failed');
  return jsonb_build_object(
    'recorded', v_recorded > 0,
    'already_completed', v_recorded = 0,
    'retry_after_seconds', case when v_recorded > 0 then 300 else 0 end,
    'pending_alert_count', v_pending
  );
end;
$$;

create or replace function public.claim_ai_budget_reconciliation_sla_alerts(
  p_limit integer default 10
) returns table (
  alert_id uuid,
  alert_kind text,
  severity text,
  open_count integer,
  sla_breached_count integer,
  oldest_age_bucket text,
  payload_version integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_limit not between 1 and 100 then
    raise exception 'invalid_reconciliation_alert_claim_limit';
  end if;

  return query
  with candidates as (
    select alert.id
    from public.ai_budget_reconciliation_sla_alerts alert
    where (
        (
          alert.state in ('pending', 'retryable_failed')
          and alert.available_at <= now()
        )
        or (
          alert.state = 'claimed'
          and alert.claim_expires_at <= now()
        )
      )
      and alert.delivery_attempts < 20
    order by alert.created_at, alert.id
    for update skip locked
    limit p_limit
  ), claimed as (
    update public.ai_budget_reconciliation_sla_alerts alert
    set state = 'claimed',
        delivery_attempts = alert.delivery_attempts + 1,
        claimed_at = now(),
        claim_expires_at = now() + interval '15 minutes',
        delivery_error_code = null
    from candidates
    where alert.id = candidates.id
    returning alert.id,
              alert.alert_kind,
              alert.severity,
              alert.open_count,
              alert.sla_breached_count,
              alert.oldest_age_bucket,
              alert.delivery_attempts
  )
  select claimed.id,
         claimed.alert_kind,
         claimed.severity,
         claimed.open_count,
         claimed.sla_breached_count,
         claimed.oldest_age_bucket,
         claimed.delivery_attempts
  from claimed;
end;
$$;

create or replace function public.resolve_ai_budget_reconciliation_sla_alert(
  p_alert_id uuid,
  p_delivered boolean,
  p_error_code text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_attempts integer;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_delivered and p_error_code is not null then
    raise exception 'delivered_alert_cannot_have_error';
  end if;
  if not p_delivered and p_error_code not in (
    'timeout', 'http_error', 'invalid_endpoint', 'unavailable', 'unknown'
  ) then
    raise exception 'reconciliation_alert_error_required';
  end if;

  select alert.delivery_attempts into v_attempts
  from public.ai_budget_reconciliation_sla_alerts alert
  where alert.id = p_alert_id
    and alert.state = 'claimed'
  for update;
  if not found then
    raise exception 'claimed_reconciliation_alert_required';
  end if;

  update public.ai_budget_reconciliation_sla_alerts
  set state = case when p_delivered then 'delivered' else 'retryable_failed' end,
      claimed_at = case when p_delivered then claimed_at else null end,
      claim_expires_at = case when p_delivered then claim_expires_at else null end,
      delivered_at = case when p_delivered then now() else null end,
      delivery_error_code = case when p_delivered then null else p_error_code end,
      available_at = case
        when p_delivered then available_at
        else now() + make_interval(
          mins => least(360, 5 * power(2, greatest(v_attempts - 1, 0)))::integer
        )
      end
  where id = p_alert_id;
  return jsonb_build_object(
    'resolved', true,
    'delivered', p_delivered,
    'retry_scheduled', not p_delivered
  );
end;
$$;

create or replace function public.purge_expired_ai_budget_scheduler_evidence(
  p_limit integer default 1000
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_runs_deleted integer := 0;
  v_alerts_deleted integer := 0;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_limit not between 1 and 10000 then
    raise exception 'invalid_scheduler_retention_limit';
  end if;

  with expired as (
    select run.id
    from public.ai_budget_reconciliation_worker_runs run
    where run.retention_until <= now()
      and run.status in ('completed', 'retryable_failed')
    order by run.retention_until
    for update skip locked
    limit p_limit
  )
  delete from public.ai_budget_reconciliation_worker_runs run
  using expired
  where run.id = expired.id;
  get diagnostics v_runs_deleted = row_count;

  with expired as (
    select alert.id
    from public.ai_budget_reconciliation_sla_alerts alert
    where alert.retention_until <= now()
      and alert.state = 'delivered'
    order by alert.retention_until
    for update skip locked
    limit p_limit
  )
  delete from public.ai_budget_reconciliation_sla_alerts alert
  using expired
  where alert.id = expired.id;
  get diagnostics v_alerts_deleted = row_count;

  return jsonb_build_object(
    'worker_runs_deleted', v_runs_deleted,
    'delivered_alerts_deleted', v_alerts_deleted
  );
end;
$$;

revoke all on function public.ai_reconciliation_age_bucket(bigint)
  from public, anon, authenticated;
revoke all on function public.run_ai_budget_reconciliation_scheduler(text)
  from public, anon, authenticated;
revoke all on function public.record_ai_budget_reconciliation_worker_failure(
  text, text
) from public, anon, authenticated;
revoke all on function public.claim_ai_budget_reconciliation_sla_alerts(integer)
  from public, anon, authenticated;
revoke all on function public.resolve_ai_budget_reconciliation_sla_alert(
  uuid, boolean, text
) from public, anon, authenticated;
revoke all on function public.purge_expired_ai_budget_scheduler_evidence(integer)
  from public, anon, authenticated;

grant execute on function public.run_ai_budget_reconciliation_scheduler(text)
  to service_role;
grant execute on function public.record_ai_budget_reconciliation_worker_failure(
  text, text
) to service_role;
grant execute on function public.claim_ai_budget_reconciliation_sla_alerts(integer)
  to service_role;
grant execute on function public.resolve_ai_budget_reconciliation_sla_alert(
  uuid, boolean, text
) to service_role;
grant execute on function public.purge_expired_ai_budget_scheduler_evidence(integer)
  to service_role;

commit;
