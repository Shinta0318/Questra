-- QST-453 PostgreSQL property checks. Run only on the isolated candidate DB.
-- The persistent ledger checks are read-only. The randomized model uses TEMP
-- tables and the whole script rolls back.
begin;

select count(*) = 0 as counters_match_reservation_ledger
from (
  select
    coalesce(counter.user_id, ledger.user_id) as user_id,
    coalesce(counter.operation, ledger.operation) as operation,
    coalesce(counter.period_start, ledger.period_start) as period_start,
    coalesce(counter.usage_count, 0) = coalesce(ledger.usage_count, 0)
      and coalesce(counter.reserved_count, 0) = coalesce(ledger.reserved_count, 0)
      and coalesce(counter.settled_count, 0) = coalesce(ledger.settled_count, 0)
      and coalesce(counter.reserved_cost_micros, 0) =
        coalesce(ledger.reserved_cost_micros, 0)
      and coalesce(counter.actual_cost_micros, 0) =
        coalesce(ledger.actual_cost_micros, 0) as matches
  from public.ai_usage_counters counter
  full join (
    select
      reservation.user_id,
      reservation.operation,
      reservation.period_start,
      count(*) filter (
        where reservation.status in ('reserved', 'settled', 'expired')
      )::integer as usage_count,
      count(*) filter (where reservation.status = 'reserved')::integer
        as reserved_count,
      count(*) filter (where reservation.status = 'settled')::integer
        as settled_count,
      coalesce(sum(reservation.reserved_cost_micros) filter (
        where reservation.status = 'reserved'
      ), 0)::bigint as reserved_cost_micros,
      coalesce(sum(reservation.actual_cost_micros) filter (
        where reservation.status = 'settled'
      ), 0)::bigint as actual_cost_micros
    from public.ai_budget_reservations reservation
    group by reservation.user_id, reservation.operation, reservation.period_start
  ) ledger
    on ledger.user_id = counter.user_id
    and ledger.operation = counter.operation
    and ledger.period_start = counter.period_start
) comparison
where not comparison.matches;

select count(*) = 0 as no_duplicate_idempotency_or_receipt_replay
from (
  select reservation.user_id::text || ':' || reservation.operation || ':' ||
      reservation.idempotency_key as identity
  from public.ai_budget_reservations reservation
  group by reservation.user_id, reservation.operation, reservation.idempotency_key
  having count(*) > 1
  union all
  select receipt.provider_interaction_id
  from public.ai_provider_execution_receipts receipt
  where receipt.provider_interaction_id is not null
  group by receipt.provider_interaction_id
  having count(*) > 1
) duplicate;

select count(*) = 0 as reconciliation_owner_boundary_is_intact
from public.ai_budget_reconciliation_cases review
join public.ai_budget_reservations reservation
  on reservation.id = review.reservation_id
where review.user_id <> reservation.user_id
  or review.trace_id <> reservation.trace_id;

select count(*) = 0 as ledger_numbers_are_nonnegative
from public.ai_usage_counters counter
where counter.usage_count < 0
  or counter.reserved_count < 0
  or counter.settled_count < 0
  or counter.reserved_cost_micros < 0
  or counter.actual_cost_micros < 0;

select position(
  'FOR UPDATE SKIP LOCKED'
  in upper(pg_get_functiondef(
    'public.claim_ai_budget_reconciliation_cases(uuid,integer,interval)'::regprocedure
  ))
) > 0 as concurrent_claims_use_skip_locked;

select position(
  'budget_correction_stale_snapshot'
  in pg_get_functiondef(
    'public.apply_ai_budget_correction(uuid,uuid)'::regprocedure
  )
) > 0 as stale_correction_is_rejected;

create temp table qst_453_property_reservations (
  id integer generated always as identity primary key,
  status text not null check (status in ('reserved', 'settled', 'released', 'expired')),
  reserved_cost bigint not null check (reserved_cost >= 0),
  actual_cost bigint check (actual_cost is null or actual_cost >= 0)
) on commit drop;

create temp table qst_453_property_counter (
  singleton boolean primary key default true check (singleton),
  usage_count integer not null default 0 check (usage_count >= 0),
  reserved_count integer not null default 0 check (reserved_count >= 0),
  settled_count integer not null default 0 check (settled_count >= 0),
  reserved_cost bigint not null default 0 check (reserved_cost >= 0),
  actual_cost bigint not null default 0 check (actual_cost >= 0)
) on commit drop;

insert into qst_453_property_counter default values;

do $$
declare
  v_iteration integer;
  v_action integer;
  v_id integer;
  v_reserved bigint;
  v_actual bigint;
  v_delta bigint;
  v_expected record;
  v_counter qst_453_property_counter%rowtype;
begin
  perform setseed(0.453);
  for v_iteration in 1..500 loop
    v_action := floor(random() * 5)::integer;

    if v_action = 0 or not exists (
      select 1 from qst_453_property_reservations where status = 'reserved'
    ) then
      v_reserved := 1 + floor(random() * 10000)::bigint;
      insert into qst_453_property_reservations(status, reserved_cost)
      values ('reserved', v_reserved);
      update qst_453_property_counter
      set usage_count = usage_count + 1,
          reserved_count = reserved_count + 1,
          reserved_cost = reserved_cost + v_reserved;
    elsif v_action in (1, 2, 3) then
      select id, reserved_cost into v_id, v_reserved
      from qst_453_property_reservations
      where status = 'reserved'
      order by random()
      limit 1;
      if v_action = 1 then
        v_actual := floor(random() * 10000)::bigint;
        update qst_453_property_reservations
        set status = 'settled', actual_cost = v_actual where id = v_id;
        update qst_453_property_counter
        set reserved_count = reserved_count - 1,
            settled_count = settled_count + 1,
            reserved_cost = reserved_cost - v_reserved,
            actual_cost = actual_cost + v_actual;
      elsif v_action = 2 then
        update qst_453_property_reservations set status = 'released' where id = v_id;
        update qst_453_property_counter
        set usage_count = usage_count - 1,
            reserved_count = reserved_count - 1,
            reserved_cost = reserved_cost - v_reserved;
      else
        update qst_453_property_reservations set status = 'expired' where id = v_id;
        update qst_453_property_counter
        set reserved_count = reserved_count - 1,
            reserved_cost = reserved_cost - v_reserved;
      end if;
    elsif exists (
      select 1 from qst_453_property_reservations where status = 'settled'
    ) then
      select id, actual_cost into v_id, v_actual
      from qst_453_property_reservations
      where status = 'settled'
      order by random()
      limit 1;
      v_delta := floor(random() * 1000)::bigint - least(v_actual, 500);
      update qst_453_property_reservations
      set actual_cost = actual_cost + v_delta where id = v_id;
      update qst_453_property_counter
      set actual_cost = actual_cost + v_delta;
    end if;

    select
      count(*) filter (where status in ('reserved', 'settled', 'expired'))
        as usage_count,
      count(*) filter (where status = 'reserved') as reserved_count,
      count(*) filter (where status = 'settled') as settled_count,
      coalesce(sum(reserved_cost) filter (where status = 'reserved'), 0)
        as reserved_cost,
      coalesce(sum(actual_cost) filter (where status = 'settled'), 0)
        as actual_cost
    into v_expected
    from qst_453_property_reservations;
    select * into v_counter from qst_453_property_counter;

    if v_counter.usage_count <> v_expected.usage_count
      or v_counter.reserved_count <> v_expected.reserved_count
      or v_counter.settled_count <> v_expected.settled_count
      or v_counter.reserved_cost <> v_expected.reserved_cost
      or v_counter.actual_cost <> v_expected.actual_cost then
      raise exception 'qst_453_random_property_failed_at_iteration_%', v_iteration;
    end if;
  end loop;
end;
$$;

rollback;
