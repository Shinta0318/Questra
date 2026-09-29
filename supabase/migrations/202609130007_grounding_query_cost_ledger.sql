begin;

create table if not exists public.ai_grounding_cost_rates (
  provider text not null check (provider in ('gemini')),
  tool_name text not null check (tool_name = 'google_search'),
  rate_version text not null unique check (
    rate_version ~ '^[a-z0-9][a-z0-9._-]{7,79}$'
  ),
  billing_unit text not null check (billing_unit = 'unique_non_empty_query'),
  micros_per_unit bigint not null check (micros_per_unit >= 0),
  included_monthly_units integer not null default 0 check (
    included_monthly_units >= 0
  ),
  allocation_policy text not null check (
    allocation_policy = 'conservative_gross_rate'
  ),
  source_uri text not null check (source_uri like 'https://%'),
  effective_from timestamptz not null,
  valid_until timestamptz,
  created_at timestamptz not null default now(),
  primary key (provider, tool_name, effective_from),
  check (valid_until is null or valid_until > effective_from)
);

insert into public.ai_grounding_cost_rates (
  provider,
  tool_name,
  rate_version,
  billing_unit,
  micros_per_unit,
  included_monthly_units,
  allocation_policy,
  source_uri,
  effective_from
) values (
  'gemini',
  'google_search',
  'gemini_google_search_query_20260913',
  'unique_non_empty_query',
  14000,
  5000,
  'conservative_gross_rate',
  'https://ai.google.dev/gemini-api/docs/pricing',
  '2026-09-13T00:00:00Z'
) on conflict (provider, tool_name, effective_from) do nothing;

create table if not exists public.ai_grounding_budget_reservations (
  reservation_id uuid primary key references public.ai_budget_reservations(id)
    on delete cascade,
  provider text not null check (provider = 'gemini'),
  tool_name text not null check (tool_name = 'google_search'),
  status text not null default 'reserved' check (
    status in ('reserved', 'settled', 'released')
  ),
  period_start date not null,
  reserved_query_count integer not null check (
    reserved_query_count between 1 and 20
  ),
  actual_query_count integer check (
    actual_query_count is null or actual_query_count between 0 and 20
  ),
  rate_version text not null references public.ai_grounding_cost_rates(rate_version)
    on delete restrict,
  rate_effective_from timestamptz not null,
  reserved_micros_per_query bigint not null check (
    reserved_micros_per_query >= 0
  ),
  reserved_cost_micros bigint not null check (reserved_cost_micros >= 0),
  actual_cost_micros bigint check (
    actual_cost_micros is null or actual_cost_micros >= 0
  ),
  settlement_evidence_digest text check (
    settlement_evidence_digest is null
    or settlement_evidence_digest ~ '^[0-9a-f]{64}$'
  ),
  reserved_at timestamptz not null default now(),
  expires_at timestamptz not null,
  settled_at timestamptz,
  released_at timestamptz,
  check (
    (
      status = 'reserved'
      and actual_query_count is null
      and actual_cost_micros is null
      and settled_at is null
      and released_at is null
    )
    or (
      status = 'settled'
      and actual_query_count is not null
      and actual_cost_micros is not null
      and settlement_evidence_digest is not null
      and settled_at is not null
      and released_at is null
    )
    or (
      status = 'released'
      and actual_query_count is null
      and actual_cost_micros is null
      and settled_at is null
      and released_at is not null
    )
  )
);

create table if not exists public.ai_grounding_monthly_counters (
  period_start date not null,
  provider text not null check (provider = 'gemini'),
  tool_name text not null check (tool_name = 'google_search'),
  rate_version text not null references public.ai_grounding_cost_rates(rate_version)
    on delete restrict,
  reserved_query_count integer not null default 0 check (
    reserved_query_count >= 0
  ),
  settled_query_count integer not null default 0 check (
    settled_query_count >= 0
  ),
  released_query_count integer not null default 0 check (
    released_query_count >= 0
  ),
  reserved_cost_micros bigint not null default 0 check (
    reserved_cost_micros >= 0
  ),
  actual_cost_micros bigint not null default 0 check (
    actual_cost_micros >= 0
  ),
  updated_at timestamptz not null default now(),
  primary key (period_start, provider, tool_name, rate_version)
);

create index if not exists ai_grounding_reservation_status_idx
  on public.ai_grounding_budget_reservations (status, expires_at);

alter table public.ai_grounding_cost_rates enable row level security;
alter table public.ai_grounding_budget_reservations enable row level security;
alter table public.ai_grounding_monthly_counters enable row level security;

revoke all on public.ai_grounding_cost_rates from public, anon, authenticated;
revoke all on public.ai_grounding_budget_reservations
  from public, anon, authenticated;
revoke all on public.ai_grounding_monthly_counters
  from public, anon, authenticated;

create or replace function public.protect_ai_grounding_cost_rate_history()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if old.effective_from <= now() then
    raise exception 'effective_ai_grounding_cost_rate_is_immutable';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists protect_ai_grounding_cost_rate_history
  on public.ai_grounding_cost_rates;
create trigger protect_ai_grounding_cost_rate_history
before update or delete on public.ai_grounding_cost_rates
for each row execute function public.protect_ai_grounding_cost_rate_history();

create or replace function public.reserve_ai_grounding_budget(
  p_reservation_id uuid,
  p_max_query_count integer
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_base public.ai_budget_reservations%rowtype;
  v_rate public.ai_grounding_cost_rates%rowtype;
  v_existing public.ai_grounding_budget_reservations%rowtype;
  v_reserved_cost bigint;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_max_query_count not between 1 and 20 then
    raise exception 'invalid_grounding_query_reservation';
  end if;

  select * into v_base
  from public.ai_budget_reservations
  where id = p_reservation_id
  for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;
  if v_base.status <> 'reserved' or v_base.expires_at <= now() then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'base_reservation_not_active'
    );
  end if;
  if v_base.provider <> 'gemini' then
    raise exception 'grounding_provider_not_supported';
  end if;

  select * into v_existing
  from public.ai_grounding_budget_reservations
  where reservation_id = p_reservation_id
  for update;
  if found then
    if v_existing.status = 'reserved'
      and v_existing.expires_at > now()
      and v_existing.reserved_query_count >= p_max_query_count then
      return jsonb_build_object(
        'allowed', true,
        'idempotent', true,
        'reserved_query_count', v_existing.reserved_query_count,
        'rate_version', v_existing.rate_version
      );
    end if;
    return jsonb_build_object(
      'allowed', false,
      'reason', 'grounding_reservation_not_resumable'
    );
  end if;

  select * into v_rate
  from public.ai_grounding_cost_rates rate
  where rate.provider = v_base.provider
    and rate.tool_name = 'google_search'
    and rate.effective_from <= v_base.pricing_effective_at
    and (rate.valid_until is null or rate.valid_until > v_base.pricing_effective_at)
  order by rate.effective_from desc
  limit 1;
  if not found then raise exception 'ai_grounding_cost_rate_missing'; end if;

  v_reserved_cost := p_max_query_count::bigint * v_rate.micros_per_unit;
  insert into public.ai_grounding_budget_reservations (
    reservation_id,
    provider,
    tool_name,
    period_start,
    reserved_query_count,
    rate_version,
    rate_effective_from,
    reserved_micros_per_query,
    reserved_cost_micros,
    expires_at
  ) values (
    v_base.id,
    v_base.provider,
    'google_search',
    v_base.period_start,
    p_max_query_count,
    v_rate.rate_version,
    v_rate.effective_from,
    v_rate.micros_per_unit,
    v_reserved_cost,
    v_base.expires_at
  );

  insert into public.ai_grounding_monthly_counters (
    period_start,
    provider,
    tool_name,
    rate_version,
    reserved_query_count,
    reserved_cost_micros
  ) values (
    v_base.period_start,
    v_base.provider,
    'google_search',
    v_rate.rate_version,
    p_max_query_count,
    v_reserved_cost
  ) on conflict (period_start, provider, tool_name, rate_version)
  do update set
    reserved_query_count =
      public.ai_grounding_monthly_counters.reserved_query_count
      + excluded.reserved_query_count,
    reserved_cost_micros =
      public.ai_grounding_monthly_counters.reserved_cost_micros
      + excluded.reserved_cost_micros,
    updated_at = now();

  return jsonb_build_object(
    'allowed', true,
    'idempotent', false,
    'reserved_query_count', p_max_query_count,
    'rate_version', v_rate.rate_version
  );
end;
$$;

alter table public.ai_provider_execution_receipts
  add column if not exists grounding_query_count integer not null default 0,
  add column if not exists grounding_evidence_version text;

alter table public.ai_provider_execution_receipts
  add constraint ai_provider_receipt_grounding_query_count_check check (
    grounding_query_count between 0 and 20
  ),
  add constraint ai_provider_receipt_grounding_evidence_check check (
    (
      grounding_query_count = 0
      and grounding_evidence_version is null
    )
    or (
      grounding_query_count > 0
      and grounding_evidence_version = 'gemini_interactions_google_search_v1'
    )
  );

create or replace function public.record_ai_provider_execution_receipt_v2(
  p_reservation_id uuid,
  p_provider_interaction_id text,
  p_model_name text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_finish_reason text,
  p_trace_id uuid,
  p_grounding_query_count integer
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reservation public.ai_budget_reservations%rowtype;
  v_existing public.ai_provider_execution_receipts%rowtype;
  v_digest text;
  v_grounding_version text;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_input_tokens not between 0 and 200000
    or p_output_tokens not between 0 and 200000
    or p_grounding_query_count not between 0 and 20 then
    raise exception 'invalid_provider_usage';
  end if;
  if char_length(p_model_name) not between 1 and 120
    or char_length(p_finish_reason) not between 1 and 80
    or (
      p_provider_interaction_id is not null
      and char_length(p_provider_interaction_id) not between 1 and 240
    ) then
    raise exception 'invalid_provider_receipt';
  end if;

  select * into v_reservation
  from public.ai_budget_reservations
  where id = p_reservation_id
  for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;
  if v_reservation.trace_id <> p_trace_id then
    raise exception 'ai_reservation_trace_mismatch';
  end if;
  if p_grounding_query_count > 0 and v_reservation.provider <> 'gemini' then
    raise exception 'grounding_provider_not_supported';
  end if;
  v_grounding_version := case
    when p_grounding_query_count > 0
      then 'gemini_interactions_google_search_v1'
    else null
  end;

  if p_grounding_query_count = 0 then
    v_digest := encode(digest(concat_ws('|',
      p_reservation_id::text,
      v_reservation.provider,
      coalesce(p_provider_interaction_id, ''),
      p_model_name,
      p_input_tokens::text,
      p_output_tokens::text,
      p_finish_reason,
      p_trace_id::text
    ), 'sha256'), 'hex');
  else
    v_digest := encode(digest(concat_ws('|',
      p_reservation_id::text,
      v_reservation.provider,
      coalesce(p_provider_interaction_id, ''),
      p_model_name,
      p_input_tokens::text,
      p_output_tokens::text,
      p_finish_reason,
      p_trace_id::text,
      p_grounding_query_count::text,
      v_grounding_version
    ), 'sha256'), 'hex');
  end if;

  select * into v_existing
  from public.ai_provider_execution_receipts
  where reservation_id = p_reservation_id;
  if found then
    if v_existing.evidence_digest <> v_digest then
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
        v_reservation.id,
        v_reservation.trace_id,
        v_existing.evidence_digest,
        'evidence_conflict',
        'provider_execution_receipt_conflict'
      );
      return jsonb_build_object(
        'recorded', false,
        'reason', 'provider_execution_receipt_conflict',
        'operator_review', true
      );
    end if;
    return jsonb_build_object(
      'recorded', true,
      'idempotent', true,
      'evidence_digest', v_digest
    );
  end if;

  insert into public.ai_provider_execution_receipts (
    reservation_id,
    user_id,
    trace_id,
    provider,
    provider_interaction_id,
    model_name,
    input_tokens,
    output_tokens,
    finish_reason,
    evidence_digest,
    grounding_query_count,
    grounding_evidence_version
  ) values (
    p_reservation_id,
    v_reservation.user_id,
    p_trace_id,
    v_reservation.provider,
    nullif(p_provider_interaction_id, ''),
    p_model_name,
    p_input_tokens,
    p_output_tokens,
    p_finish_reason,
    v_digest,
    p_grounding_query_count,
    v_grounding_version
  );
  return jsonb_build_object(
    'recorded', true,
    'idempotent', false,
    'evidence_digest', v_digest
  );
end;
$$;

create or replace function public.release_grounding_reservation_with_base()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_grounding public.ai_grounding_budget_reservations%rowtype;
begin
  if old.status = 'reserved' and new.status in ('released', 'expired') then
    select * into v_grounding
    from public.ai_grounding_budget_reservations
    where reservation_id = new.id
    for update;

    if found and v_grounding.status = 'reserved' then
      update public.ai_grounding_budget_reservations
      set status = 'released',
          released_at = now()
      where reservation_id = new.id;

      update public.ai_grounding_monthly_counters
      set reserved_query_count = greatest(
            reserved_query_count - v_grounding.reserved_query_count,
            0
          ),
          released_query_count =
            released_query_count + v_grounding.reserved_query_count,
          reserved_cost_micros = greatest(
            reserved_cost_micros - v_grounding.reserved_cost_micros,
            0
          ),
          updated_at = now()
      where period_start = v_grounding.period_start
        and provider = v_grounding.provider
        and tool_name = v_grounding.tool_name
        and rate_version = v_grounding.rate_version;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists release_grounding_reservation_with_base
  on public.ai_budget_reservations;
create trigger release_grounding_reservation_with_base
after update of status on public.ai_budget_reservations
for each row execute function public.release_grounding_reservation_with_base();

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
  v_rate public.ai_model_cost_rates%rowtype;
  v_receipt public.ai_provider_execution_receipts%rowtype;
  v_grounding public.ai_grounding_budget_reservations%rowtype;
  v_token_cost bigint;
  v_grounding_cost bigint := 0;
  v_grounding_queries integer := 0;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_input_tokens not between 0 and 200000
    or p_output_tokens not between 0 and 200000 then
    raise exception 'invalid_provider_usage';
  end if;

  select * into v_row
  from public.ai_budget_reservations
  where id = p_reservation_id
  for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;

  select * into v_grounding
  from public.ai_grounding_budget_reservations
  where reservation_id = p_reservation_id
  for update;

  if v_row.status = 'settled' then
    if found and v_grounding.status <> 'settled' then
      raise exception 'ai_grounding_settlement_incomplete';
    end if;
    return jsonb_build_object(
      'settled', true,
      'idempotent', true,
      'token_cost_micros', v_row.actual_cost_micros,
      'grounding_cost_micros', coalesce(v_grounding.actual_cost_micros, 0),
      'total_cost_micros',
        coalesce(v_row.actual_cost_micros, 0)
        + coalesce(v_grounding.actual_cost_micros, 0)
    );
  end if;
  if v_row.status <> 'reserved' then
    raise exception 'ai_reservation_not_settleable';
  end if;

  select * into v_receipt
  from public.ai_provider_execution_receipts
  where reservation_id = p_reservation_id;
  if not found then raise exception 'provider_execution_receipt_required'; end if;
  if v_receipt.model_name <> p_model_name
    or v_receipt.input_tokens <> p_input_tokens
    or v_receipt.output_tokens <> p_output_tokens then
    raise exception 'provider_execution_receipt_mismatch';
  end if;

  select * into v_rate
  from public.ai_model_cost_rates
  where provider = v_row.provider
    and model_name = p_model_name
    and effective_from <= v_row.pricing_effective_at
    and (valid_until is null or valid_until > v_row.pricing_effective_at)
  order by effective_from desc
  limit 1;
  if not found then
    raise exception 'ai_model_cost_rate_missing_at_reservation';
  end if;
  v_token_cost := ceil(
    (p_input_tokens::numeric * v_rate.input_micros_per_million_tokens
      + p_output_tokens::numeric * v_rate.output_micros_per_million_tokens)
    / 1000000
  )::bigint;

  select * into v_grounding
  from public.ai_grounding_budget_reservations
  where reservation_id = p_reservation_id
  for update;
  if found then
    if v_grounding.status <> 'reserved' then
      raise exception 'ai_grounding_reservation_not_settleable';
    end if;
    if v_receipt.grounding_evidence_version
      is distinct from 'gemini_interactions_google_search_v1' then
      raise exception 'ai_grounding_provider_evidence_required';
    end if;
    if v_receipt.grounding_query_count > v_grounding.reserved_query_count then
      raise exception 'ai_grounding_query_count_exceeds_reservation';
    end if;
    v_grounding_queries := v_receipt.grounding_query_count;
    v_grounding_cost :=
      v_grounding_queries::bigint * v_grounding.reserved_micros_per_query;
  elsif v_receipt.grounding_query_count > 0 then
    raise exception 'ai_grounding_budget_not_reserved';
  end if;

  update public.ai_budget_reservations
  set status = 'settled',
      model_name = p_model_name,
      actual_input_tokens = p_input_tokens,
      actual_output_tokens = p_output_tokens,
      actual_cost_micros = v_token_cost,
      actual_rate_effective_from = v_rate.effective_from,
      actual_input_rate_micros = v_rate.input_micros_per_million_tokens,
      actual_output_rate_micros = v_rate.output_micros_per_million_tokens,
      actual_pricing_source_uri = v_rate.source_uri,
      finish_reason = left(p_finish_reason, 80),
      settled_at = now()
  where id = p_reservation_id;

  update public.ai_usage_counters
  set reserved_count = greatest(reserved_count - 1, 0),
      settled_count = settled_count + 1,
      reserved_cost_micros = greatest(
        reserved_cost_micros - v_row.reserved_cost_micros,
        0
      ),
      actual_cost_micros = actual_cost_micros + v_token_cost,
      updated_at = now()
  where user_id = v_row.user_id
    and operation = v_row.operation
    and period_start = v_row.period_start;

  if v_grounding.reservation_id is not null then
    update public.ai_grounding_budget_reservations
    set status = 'settled',
        actual_query_count = v_grounding_queries,
        actual_cost_micros = v_grounding_cost,
        settlement_evidence_digest = v_receipt.evidence_digest,
        settled_at = now()
    where reservation_id = p_reservation_id;

    update public.ai_grounding_monthly_counters
    set reserved_query_count = greatest(
          reserved_query_count - v_grounding.reserved_query_count,
          0
        ),
        settled_query_count = settled_query_count + v_grounding_queries,
        reserved_cost_micros = greatest(
          reserved_cost_micros - v_grounding.reserved_cost_micros,
          0
        ),
        actual_cost_micros = actual_cost_micros + v_grounding_cost,
        updated_at = now()
    where period_start = v_grounding.period_start
      and provider = v_grounding.provider
      and tool_name = v_grounding.tool_name
      and rate_version = v_grounding.rate_version;
  end if;

  return jsonb_build_object(
    'settled', true,
    'idempotent', false,
    'token_cost_micros', v_token_cost,
    'grounding_query_count', v_grounding_queries,
    'grounding_cost_micros', v_grounding_cost,
    'total_cost_micros', v_token_cost + v_grounding_cost,
    'pricing_effective_at', v_row.pricing_effective_at,
    'rate_effective_from', v_rate.effective_from
  );
end;
$$;

create or replace view public.ai_grounding_cost_daily
with (security_invoker = true)
as
select
  date_trunc('day', settled_at) as usage_day,
  provider,
  tool_name,
  rate_version,
  count(*) as settled_calls,
  coalesce(sum(actual_query_count), 0) as settled_query_count,
  coalesce(sum(actual_cost_micros), 0) as actual_cost_micros
from public.ai_grounding_budget_reservations
where status = 'settled'
group by
  date_trunc('day', settled_at),
  provider,
  tool_name,
  rate_version;

revoke all on public.ai_grounding_cost_daily
  from public, anon, authenticated;
grant select on public.ai_grounding_cost_daily to service_role;

revoke all on function public.protect_ai_grounding_cost_rate_history()
  from public;
revoke all on function public.release_grounding_reservation_with_base()
  from public;
revoke all on function public.reserve_ai_grounding_budget(uuid, integer)
  from public;
revoke all on function public.record_ai_provider_execution_receipt_v2(
  uuid, text, text, integer, integer, text, uuid, integer
) from public;
revoke all on function public.settle_ai_usage_budget(
  uuid, text, integer, integer, text
) from public;
grant execute on function public.reserve_ai_grounding_budget(uuid, integer)
  to service_role;
grant execute on function public.record_ai_provider_execution_receipt_v2(
  uuid, text, text, integer, integer, text, uuid, integer
) to service_role;
grant execute on function public.settle_ai_usage_budget(
  uuid, text, integer, integer, text
) to service_role;

commit;
