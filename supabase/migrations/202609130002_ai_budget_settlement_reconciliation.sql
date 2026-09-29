begin;

create table if not exists public.ai_provider_execution_receipts (
  reservation_id uuid primary key references public.ai_budget_reservations(id)
    on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  trace_id uuid not null,
  provider text not null check (provider in ('gemini', 'openai')),
  provider_interaction_id text check (
    provider_interaction_id is null
    or char_length(provider_interaction_id) between 1 and 240
  ),
  model_name text not null check (char_length(model_name) between 1 and 120),
  input_tokens integer not null check (input_tokens between 0 and 200000),
  output_tokens integer not null check (output_tokens between 0 and 200000),
  finish_reason text not null check (char_length(finish_reason) between 1 and 80),
  evidence_source text not null default 'edge_provider_response' check (
    evidence_source = 'edge_provider_response'
  ),
  evidence_digest text not null unique check (evidence_digest ~ '^[0-9a-f]{64}$'),
  recorded_at timestamptz not null default now()
);

create unique index if not exists ai_provider_execution_receipts_interaction_idx
  on public.ai_provider_execution_receipts (provider, provider_interaction_id)
  where provider_interaction_id is not null;

create table if not exists public.ai_budget_reconciliation_attempts (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.ai_budget_reservations(id)
    on delete cascade,
  trace_id uuid not null,
  evidence_digest text check (
    evidence_digest is null or evidence_digest ~ '^[0-9a-f]{64}$'
  ),
  outcome text not null check (outcome in (
    'settled', 'already_settled', 'operator_review', 'status_conflict',
    'evidence_conflict', 'settlement_failed'
  )),
  reason text not null check (char_length(reason) between 1 and 160),
  attempted_at timestamptz not null default now()
);

create index if not exists ai_budget_reconciliation_attempts_reservation_idx
  on public.ai_budget_reconciliation_attempts (reservation_id, attempted_at desc);

create table if not exists public.ai_budget_reconciliation_cases (
  reservation_id uuid primary key references public.ai_budget_reservations(id)
    on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  trace_id uuid not null,
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  reason text not null check (reason in (
    'execution_unknown', 'reservation_status_conflict',
    'execution_evidence_conflict', 'settlement_failed'
  )),
  opened_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution_note text check (
    resolution_note is null or char_length(resolution_note) <= 500
  )
);

alter table public.ai_provider_execution_receipts enable row level security;
alter table public.ai_budget_reconciliation_attempts enable row level security;
alter table public.ai_budget_reconciliation_cases enable row level security;
revoke all on public.ai_provider_execution_receipts from anon, authenticated;
revoke all on public.ai_budget_reconciliation_attempts from anon, authenticated;
revoke all on public.ai_budget_reconciliation_cases from anon, authenticated;

create or replace function public.record_ai_provider_execution_receipt(
  p_reservation_id uuid,
  p_provider_interaction_id text,
  p_model_name text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_finish_reason text,
  p_trace_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reservation public.ai_budget_reservations%rowtype;
  v_existing public.ai_provider_execution_receipts%rowtype;
  v_digest text;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_input_tokens not between 0 and 200000
    or p_output_tokens not between 0 and 200000 then
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
    evidence_digest
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
    v_digest
  );
  return jsonb_build_object(
    'recorded', true,
    'idempotent', false,
    'evidence_digest', v_digest
  );
end;
$$;

create or replace function public.reconcile_ai_usage_budget(
  p_reservation_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reservation public.ai_budget_reservations%rowtype;
  v_receipt public.ai_provider_execution_receipts%rowtype;
  v_result jsonb;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  select * into v_reservation
  from public.ai_budget_reservations
  where id = p_reservation_id
  for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;
  select * into v_receipt
  from public.ai_provider_execution_receipts
  where reservation_id = p_reservation_id;

  if not found then
    insert into public.ai_budget_reconciliation_cases (
      reservation_id, user_id, trace_id, reason
    ) values (
      v_reservation.id,
      v_reservation.user_id,
      v_reservation.trace_id,
      'execution_unknown'
    ) on conflict (reservation_id) do update set
      status = 'open',
      reason = excluded.reason,
      resolved_at = null;
    insert into public.ai_budget_reconciliation_attempts (
      reservation_id, trace_id, outcome, reason
    ) values (
      v_reservation.id,
      v_reservation.trace_id,
      'operator_review',
      'provider_execution_receipt_missing'
    );
    return jsonb_build_object(
      'reconciled', false,
      'reason', 'provider_execution_receipt_missing',
      'operator_review', true
    );
  end if;

  if v_reservation.status = 'settled' then
    if v_reservation.model_name = v_receipt.model_name
      and v_reservation.actual_input_tokens = v_receipt.input_tokens
      and v_reservation.actual_output_tokens = v_receipt.output_tokens then
      update public.ai_budget_reconciliation_cases
      set status = 'resolved',
          resolved_at = now(),
          resolution_note = 'matching settlement verified from provider receipt'
      where reservation_id = v_reservation.id
        and status = 'open';
      insert into public.ai_budget_reconciliation_attempts (
        reservation_id, trace_id, evidence_digest, outcome, reason
      ) values (
        v_reservation.id,
        v_reservation.trace_id,
        v_receipt.evidence_digest,
        'already_settled',
        'matching_settlement_already_committed'
      );
      return jsonb_build_object(
        'reconciled', true,
        'idempotent', true,
        'actual_cost_micros', v_reservation.actual_cost_micros
      );
    end if;
    insert into public.ai_budget_reconciliation_cases (
      reservation_id, user_id, trace_id, reason
    ) values (
      v_reservation.id,
      v_reservation.user_id,
      v_reservation.trace_id,
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
      v_receipt.evidence_digest,
      'evidence_conflict',
      'settled_usage_does_not_match_receipt'
    );
    return jsonb_build_object(
      'reconciled', false,
      'reason', 'settled_usage_does_not_match_receipt',
      'operator_review', true
    );
  end if;

  if v_reservation.status <> 'reserved' then
    insert into public.ai_budget_reconciliation_cases (
      reservation_id, user_id, trace_id, reason
    ) values (
      v_reservation.id,
      v_reservation.user_id,
      v_reservation.trace_id,
      'reservation_status_conflict'
    ) on conflict (reservation_id) do update set
      status = 'open',
      reason = excluded.reason,
      resolved_at = null;
    insert into public.ai_budget_reconciliation_attempts (
      reservation_id, trace_id, evidence_digest, outcome, reason
    ) values (
      v_reservation.id,
      v_reservation.trace_id,
      v_receipt.evidence_digest,
      'status_conflict',
      'reservation_is_not_settleable'
    );
    return jsonb_build_object(
      'reconciled', false,
      'reason', 'reservation_is_not_settleable',
      'operator_review', true
    );
  end if;

  begin
    v_result := public.settle_ai_usage_budget(
      v_reservation.id,
      v_receipt.model_name,
      v_receipt.input_tokens,
      v_receipt.output_tokens,
      v_receipt.finish_reason
    );
    update public.ai_budget_reconciliation_cases
    set status = 'resolved',
        resolved_at = now(),
        resolution_note = 'reservation settled from provider receipt'
    where reservation_id = v_reservation.id
      and status = 'open';
    insert into public.ai_budget_reconciliation_attempts (
      reservation_id, trace_id, evidence_digest, outcome, reason
    ) values (
      v_reservation.id,
      v_reservation.trace_id,
      v_receipt.evidence_digest,
      'settled',
      'settled_from_provider_execution_receipt'
    );
    return jsonb_build_object(
      'reconciled', true,
      'idempotent', false,
      'settlement', v_result
    );
  exception when others then
    insert into public.ai_budget_reconciliation_cases (
      reservation_id, user_id, trace_id, reason
    ) values (
      v_reservation.id,
      v_reservation.user_id,
      v_reservation.trace_id,
      'settlement_failed'
    ) on conflict (reservation_id) do update set
      status = 'open',
      reason = excluded.reason,
      resolved_at = null;
    insert into public.ai_budget_reconciliation_attempts (
      reservation_id, trace_id, evidence_digest, outcome, reason
    ) values (
      v_reservation.id,
      v_reservation.trace_id,
      v_receipt.evidence_digest,
      'settlement_failed',
      left(sqlerrm, 160)
    );
    return jsonb_build_object(
      'reconciled', false,
      'reason', 'settlement_failed',
      'operator_review', true
    );
  end;
end;
$$;

create or replace function public.classify_stale_ai_budget_reservations(
  p_older_than interval default interval '15 minutes',
  p_limit integer default 100
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reservation public.ai_budget_reservations%rowtype;
  v_result jsonb;
  v_reconciled integer := 0;
  v_review integer := 0;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_older_than < interval '10 minutes'
    or p_older_than > interval '30 days'
    or p_limit not between 1 and 500 then
    raise exception 'invalid_reconciliation_sweep_bounds';
  end if;

  for v_reservation in
    select *
    from public.ai_budget_reservations
    where status = 'reserved'
      and expires_at <= now()
      and reserved_at <= now() - p_older_than
    order by reserved_at
    for update skip locked
    limit p_limit
  loop
    if exists (
      select 1
      from public.ai_provider_execution_receipts
      where reservation_id = v_reservation.id
    ) then
      v_result := public.reconcile_ai_usage_budget(v_reservation.id);
      if coalesce((v_result ->> 'reconciled')::boolean, false) then
        v_reconciled := v_reconciled + 1;
      else
        v_review := v_review + 1;
      end if;
    else
      update public.ai_budget_reservations
      set status = 'expired',
          release_reason = 'execution_unknown_operator_review',
          released_at = now()
      where id = v_reservation.id
        and status = 'reserved';
      update public.ai_usage_counters
      set reserved_count = greatest(reserved_count - 1, 0),
          reserved_cost_micros = greatest(
            reserved_cost_micros - v_reservation.reserved_cost_micros,
            0
          ),
          updated_at = now()
      where user_id = v_reservation.user_id
        and operation = v_reservation.operation
        and period_start = v_reservation.period_start;
      insert into public.ai_budget_reconciliation_cases (
        reservation_id, user_id, trace_id, reason
      ) values (
        v_reservation.id,
        v_reservation.user_id,
        v_reservation.trace_id,
        'execution_unknown'
      ) on conflict (reservation_id) do update set
        status = 'open',
        reason = excluded.reason,
        resolved_at = null;
      insert into public.ai_budget_reconciliation_attempts (
        reservation_id, trace_id, outcome, reason
      ) values (
        v_reservation.id,
        v_reservation.trace_id,
        'operator_review',
        'stale_reservation_without_provider_receipt'
      );
      v_review := v_review + 1;
    end if;
  end loop;
  return jsonb_build_object(
    'processed', v_reconciled + v_review,
    'reconciled', v_reconciled,
    'operator_review', v_review
  );
end;
$$;

revoke all on function public.record_ai_provider_execution_receipt(
  uuid, text, text, integer, integer, text, uuid
) from public;
revoke all on function public.reconcile_ai_usage_budget(uuid) from public;
revoke all on function public.classify_stale_ai_budget_reservations(
  interval, integer
) from public;
grant execute on function public.record_ai_provider_execution_receipt(
  uuid, text, text, integer, integer, text, uuid
) to service_role;
grant execute on function public.reconcile_ai_usage_budget(uuid)
  to service_role;
grant execute on function public.classify_stale_ai_budget_reservations(
  interval, integer
) to service_role;

commit;
