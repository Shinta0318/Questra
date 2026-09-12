begin;

alter table public.ai_model_cost_rates
  add column if not exists currency text not null default 'USD',
  add column if not exists unit text not null default 'micros_per_million_tokens',
  add column if not exists price_tier text not null default 'standard',
  add column if not exists source_checked_at date not null default current_date;

alter table public.ai_model_cost_rates
  drop constraint if exists ai_model_cost_rates_currency_check,
  add constraint ai_model_cost_rates_currency_check check (currency ~ '^[A-Z]{3}$'),
  drop constraint if exists ai_model_cost_rates_unit_check,
  add constraint ai_model_cost_rates_unit_check check (
    unit = 'micros_per_million_tokens'
  ),
  drop constraint if exists ai_model_cost_rates_price_tier_check,
  add constraint ai_model_cost_rates_price_tier_check check (
    price_tier in ('standard', 'batch', 'priority')
  );

update public.ai_model_cost_rates
set source_checked_at = date '2026-09-13',
    currency = 'USD',
    unit = 'micros_per_million_tokens',
    price_tier = 'standard'
where provider = 'gemini';

-- Google publishes a specific Standard paid-tier rollover for Gemini 3.6 Flash.
insert into public.ai_model_cost_rates (
  provider,
  model_name,
  input_micros_per_million_tokens,
  output_micros_per_million_tokens,
  source_uri,
  effective_from,
  valid_until,
  currency,
  unit,
  price_tier,
  source_checked_at
) values (
  'gemini',
  'gemini-3.6-flash',
  1500000,
  7500000,
  'https://ai.google.dev/gemini-api/docs/pricing',
  timestamptz '2027-01-01 00:00:00+00',
  null,
  'USD',
  'micros_per_million_tokens',
  'standard',
  date '2026-09-13'
)
on conflict (provider, model_name, effective_from) do nothing;

create extension if not exists btree_gist with schema extensions;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'ai_model_cost_rates_no_overlap'
      and conrelid = 'public.ai_model_cost_rates'::regclass
  ) then
    alter table public.ai_model_cost_rates
      add constraint ai_model_cost_rates_no_overlap
      exclude using gist (
        provider with =,
        model_name with =,
        tstzrange(
          effective_from,
          coalesce(valid_until, 'infinity'::timestamptz),
          '[)'
        ) with &&
      ) deferrable initially immediate;
  end if;
end;
$$;

create or replace function public.protect_ai_model_cost_rate_history()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'DELETE' then
    if old.effective_from <= now() then
      raise exception 'effective_ai_model_cost_rate_is_immutable';
    end if;
    return old;
  end if;

  if old.effective_from <= now() then
    if new.provider is distinct from old.provider
      or new.model_name is distinct from old.model_name
      or new.input_micros_per_million_tokens is distinct from
        old.input_micros_per_million_tokens
      or new.output_micros_per_million_tokens is distinct from
        old.output_micros_per_million_tokens
      or new.source_uri is distinct from old.source_uri
      or new.effective_from is distinct from old.effective_from
      or new.currency is distinct from old.currency
      or new.unit is distinct from old.unit
      or new.price_tier is distinct from old.price_tier
      or new.source_checked_at is distinct from old.source_checked_at then
      raise exception 'effective_ai_model_cost_rate_is_immutable';
    end if;
    if new.valid_until is distinct from old.valid_until
      and not (
        old.valid_until is null
        and new.valid_until is not null
        and new.valid_until > now()
      ) then
      raise exception 'effective_ai_model_cost_rate_window_is_immutable';
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists protect_ai_model_cost_rate_history
  on public.ai_model_cost_rates;
create trigger protect_ai_model_cost_rate_history
before update or delete on public.ai_model_cost_rates
for each row execute function public.protect_ai_model_cost_rate_history();

create or replace function public.verify_ai_model_cost_rate_windows()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    with ordered as (
      select provider,
        model_name,
        effective_from,
        valid_until,
        lag(valid_until) over (
          partition by provider, model_name order by effective_from
        ) as previous_valid_until,
        row_number() over (
          partition by provider, model_name order by effective_from
        ) as sequence_number,
        row_number() over (
          partition by provider, model_name order by effective_from desc
        ) as reverse_sequence_number
      from public.ai_model_cost_rates
    )
    select 1
    from ordered
    where (sequence_number > 1 and previous_valid_until is distinct from effective_from)
      or (reverse_sequence_number = 1 and valid_until is not null)
  ) then
    raise exception 'ai_model_cost_rate_window_gap_or_overlap';
  end if;
end;
$$;

create or replace function public.ai_token_cost_micros_at(
  p_provider text,
  p_model_name text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_priced_at timestamptz
) returns bigint
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_input_rate bigint;
  v_output_rate bigint;
begin
  select input_micros_per_million_tokens,
      output_micros_per_million_tokens
    into v_input_rate, v_output_rate
  from public.ai_model_cost_rates
  where provider = p_provider
    and model_name = p_model_name
    and effective_from <= p_priced_at
    and (valid_until is null or valid_until > p_priced_at)
  order by effective_from desc
  limit 1;
  if not found then raise exception 'ai_model_cost_rate_missing'; end if;
  return ceil(
    (greatest(p_input_tokens, 0)::numeric * v_input_rate +
     greatest(p_output_tokens, 0)::numeric * v_output_rate) / 1000000
  )::bigint;
end;
$$;

create or replace function public.ai_token_cost_micros(
  p_provider text,
  p_model_name text,
  p_input_tokens integer,
  p_output_tokens integer
) returns bigint
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select public.ai_token_cost_micros_at(
    p_provider,
    p_model_name,
    p_input_tokens,
    p_output_tokens,
    now()
  );
$$;

alter table public.ai_budget_reservations
  add column if not exists pricing_effective_at timestamptz,
  add column if not exists reserved_rate_effective_from timestamptz,
  add column if not exists reserved_input_rate_micros bigint,
  add column if not exists reserved_output_rate_micros bigint,
  add column if not exists reserved_pricing_source_uri text,
  add column if not exists actual_rate_effective_from timestamptz,
  add column if not exists actual_input_rate_micros bigint,
  add column if not exists actual_output_rate_micros bigint,
  add column if not exists actual_pricing_source_uri text;

with priced as (
  select reservation.id,
    reservation.reserved_at as priced_at,
    rate.effective_from,
    rate.input_micros_per_million_tokens,
    rate.output_micros_per_million_tokens,
    rate.source_uri
  from public.ai_budget_reservations as reservation
  join lateral (
    select effective_from,
      input_micros_per_million_tokens,
      output_micros_per_million_tokens,
      source_uri
    from public.ai_model_cost_rates
    where provider = reservation.provider
      and model_name = reservation.model_name
      and effective_from <= reservation.reserved_at
      and (valid_until is null or valid_until > reservation.reserved_at)
    order by effective_from desc
    limit 1
  ) as rate on true
)
update public.ai_budget_reservations as reservation
set pricing_effective_at = priced.priced_at,
    reserved_rate_effective_from = priced.effective_from,
    reserved_input_rate_micros = priced.input_micros_per_million_tokens,
    reserved_output_rate_micros = priced.output_micros_per_million_tokens,
    reserved_pricing_source_uri = priced.source_uri
from priced
where reservation.id = priced.id
  and reservation.pricing_effective_at is null;

alter table public.ai_budget_reservations
  alter column pricing_effective_at set not null,
  alter column reserved_rate_effective_from set not null,
  alter column reserved_input_rate_micros set not null,
  alter column reserved_output_rate_micros set not null,
  alter column reserved_pricing_source_uri set not null,
  add constraint ai_budget_reservations_reserved_input_rate_check check (
    reserved_input_rate_micros >= 0
  ),
  add constraint ai_budget_reservations_reserved_output_rate_check check (
    reserved_output_rate_micros >= 0
  ),
  add constraint ai_budget_reservations_actual_input_rate_check check (
    actual_input_rate_micros is null or actual_input_rate_micros >= 0
  ),
  add constraint ai_budget_reservations_actual_output_rate_check check (
    actual_output_rate_micros is null or actual_output_rate_micros >= 0
  );

create or replace function public.populate_ai_reservation_price_snapshot()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_rate public.ai_model_cost_rates%rowtype;
begin
  new.pricing_effective_at := now();
  select * into v_rate
  from public.ai_model_cost_rates
  where provider = new.provider
    and model_name = new.model_name
    and effective_from <= new.pricing_effective_at
    and (valid_until is null or valid_until > new.pricing_effective_at)
  order by effective_from desc
  limit 1;
  if not found then raise exception 'ai_model_cost_rate_missing'; end if;
  new.reserved_rate_effective_from := v_rate.effective_from;
  new.reserved_input_rate_micros := v_rate.input_micros_per_million_tokens;
  new.reserved_output_rate_micros := v_rate.output_micros_per_million_tokens;
  new.reserved_pricing_source_uri := v_rate.source_uri;
  return new;
end;
$$;

drop trigger if exists populate_ai_reservation_price_snapshot
  on public.ai_budget_reservations;
create trigger populate_ai_reservation_price_snapshot
before insert on public.ai_budget_reservations
for each row execute function public.populate_ai_reservation_price_snapshot();

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
  v_cost bigint;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  select * into v_row
  from public.ai_budget_reservations
  where id = p_reservation_id
  for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;
  if v_row.status = 'settled' then
    return jsonb_build_object(
      'settled', true,
      'idempotent', true,
      'actual_cost_micros', v_row.actual_cost_micros
    );
  end if;
  if v_row.status <> 'reserved' then
    raise exception 'ai_reservation_not_settleable';
  end if;

  -- A request crossing a pricing boundary is always charged at reservation time.
  select * into v_rate
  from public.ai_model_cost_rates
  where provider = v_row.provider
    and model_name = p_model_name
    and effective_from <= v_row.pricing_effective_at
    and (valid_until is null or valid_until > v_row.pricing_effective_at)
  order by effective_from desc
  limit 1;
  if not found then raise exception 'ai_model_cost_rate_missing_at_reservation'; end if;
  v_cost := ceil(
    (greatest(p_input_tokens, 0)::numeric *
       v_rate.input_micros_per_million_tokens +
     greatest(p_output_tokens, 0)::numeric *
       v_rate.output_micros_per_million_tokens) / 1000000
  )::bigint;

  update public.ai_budget_reservations
  set status = 'settled',
      model_name = p_model_name,
      actual_input_tokens = greatest(p_input_tokens, 0),
      actual_output_tokens = greatest(p_output_tokens, 0),
      actual_cost_micros = v_cost,
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
      actual_cost_micros = actual_cost_micros + v_cost,
      updated_at = now()
  where user_id = v_row.user_id
    and operation = v_row.operation
    and period_start = v_row.period_start;

  return jsonb_build_object(
    'settled', true,
    'idempotent', false,
    'actual_cost_micros', v_cost,
    'pricing_effective_at', v_row.pricing_effective_at,
    'rate_effective_from', v_rate.effective_from
  );
end;
$$;

revoke all on function public.ai_token_cost_micros_at(
  text, text, integer, integer, timestamptz
) from public;
revoke all on function public.verify_ai_model_cost_rate_windows() from public;
revoke all on function public.settle_ai_usage_budget(
  uuid, text, integer, integer, text
) from public;
grant execute on function public.ai_token_cost_micros_at(
  text, text, integer, integer, timestamptz
) to service_role;
grant execute on function public.verify_ai_model_cost_rate_windows()
  to service_role;
grant execute on function public.settle_ai_usage_budget(
  uuid, text, integer, integer, text
) to service_role;

select public.verify_ai_model_cost_rate_windows();

commit;
