begin;

create table if not exists public.ai_tool_continuation_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null check (operation in (
    'arc_consultation', 'quest_planning', 'basic_mission_planning',
    'mission_redesign', 'detailed_progress_review'
  )),
  trace_id uuid not null,
  idempotency_key_digest text not null check (
    idempotency_key_digest ~ '^[0-9a-f]{64}$'
  ),
  status text not null default 'running' check (
    status in ('running', 'completed', 'failed', 'cancelled')
  ),
  turn_count integer not null default 0 check (turn_count between 0 and 5),
  total_input_tokens integer not null default 0 check (
    total_input_tokens between 0 and 1000000
  ),
  total_output_tokens integer not null default 0 check (
    total_output_tokens between 0 and 1000000
  ),
  total_grounding_query_count integer not null default 0 check (
    total_grounding_query_count between 0 and 100
  ),
  total_cost_micros bigint not null default 0 check (total_cost_micros >= 0),
  failure_reason text check (
    failure_reason is null or failure_reason in (
      'timeout', 'cancelled', 'tool_failed', 'provider_failed',
      'attribution_failed'
    )
  ),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  retention_until timestamptz not null default (now() + interval '90 days'),
  unique (user_id, operation, idempotency_key_digest),
  check (
    (status = 'running' and completed_at is null and failure_reason is null)
    or (
      status = 'completed'
      and completed_at is not null
      and failure_reason is null
      and turn_count > 0
    )
    or (
      status in ('failed', 'cancelled')
      and completed_at is not null
      and failure_reason is not null
    )
  )
);

create table if not exists public.ai_tool_continuation_turns (
  run_id uuid not null references public.ai_tool_continuation_runs(id)
    on delete cascade,
  turn_number integer not null check (turn_number between 0 and 4),
  reservation_id uuid not null unique references
    public.ai_budget_reservations(id) on delete restrict,
  idempotency_key_digest text not null check (
    idempotency_key_digest ~ '^[0-9a-f]{64}$'
  ),
  attempted_models text[] not null check (
    cardinality(attempted_models) between 1 and 4
  ),
  settled_model text not null check (char_length(settled_model) between 1 and 120),
  thinking_level text not null check (
    thinking_level in ('minimal', 'low', 'medium', 'high')
  ),
  input_tokens integer not null check (input_tokens between 0 and 200000),
  output_tokens integer not null check (output_tokens between 0 and 200000),
  grounding_query_count integer not null check (
    grounding_query_count between 0 and 20
  ),
  total_cost_micros bigint not null check (total_cost_micros >= 0),
  recorded_at timestamptz not null default now(),
  primary key (run_id, turn_number),
  check (attempted_models[cardinality(attempted_models)] = settled_model)
);

create index if not exists ai_tool_continuation_runs_retention_idx
  on public.ai_tool_continuation_runs (retention_until);

alter table public.ai_tool_continuation_runs enable row level security;
alter table public.ai_tool_continuation_turns enable row level security;

revoke all on public.ai_tool_continuation_runs
  from public, anon, authenticated;
revoke all on public.ai_tool_continuation_turns
  from public, anon, authenticated;

create or replace function public.start_ai_tool_continuation_attribution(
  p_user_id uuid,
  p_operation text,
  p_idempotency_key text,
  p_trace_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_digest text;
  v_run public.ai_tool_continuation_runs%rowtype;
  v_inserted integer := 0;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_user_id is null or not exists (
    select 1 from auth.users account where account.id = p_user_id
  ) then
    raise exception 'ai_tool_continuation_user_required';
  end if;
  if p_operation not in (
    'arc_consultation', 'quest_planning', 'basic_mission_planning',
    'mission_redesign', 'detailed_progress_review'
  ) or p_idempotency_key is null
    or char_length(p_idempotency_key) not between 8 and 160
    or p_trace_id is null then
    raise exception 'invalid_ai_tool_continuation_context';
  end if;

  v_digest := encode(digest(p_idempotency_key, 'sha256'), 'hex');
  insert into public.ai_tool_continuation_runs (
    user_id, operation, trace_id, idempotency_key_digest
  ) values (
    p_user_id, p_operation, p_trace_id, v_digest
  ) on conflict (user_id, operation, idempotency_key_digest) do nothing;
  get diagnostics v_inserted = row_count;

  select * into v_run
  from public.ai_tool_continuation_runs run
  where run.user_id = p_user_id
    and run.operation = p_operation
    and run.idempotency_key_digest = v_digest
  for update;
  if v_run.trace_id <> p_trace_id then
    raise exception 'ai_tool_continuation_trace_conflict';
  end if;

  return jsonb_build_object(
    'started', true,
    'idempotent', v_inserted = 0,
    'run_id', v_run.id,
    'status', v_run.status
  );
end;
$$;

create or replace function public.record_ai_tool_continuation_turn(
  p_run_id uuid,
  p_turn_number integer,
  p_idempotency_key text,
  p_attempted_models text[]
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_run public.ai_tool_continuation_runs%rowtype;
  v_reservation public.ai_budget_reservations%rowtype;
  v_receipt public.ai_provider_execution_receipts%rowtype;
  v_existing public.ai_tool_continuation_turns%rowtype;
  v_grounding_queries integer := 0;
  v_grounding_cost bigint := 0;
  v_digest text;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_turn_number not between 0 and 4
    or p_idempotency_key is null
    or char_length(p_idempotency_key) not between 8 and 180
    or coalesce(cardinality(p_attempted_models), 0) not between 1 and 4
    or exists (
      select 1 from unnest(p_attempted_models) model_name
      where char_length(btrim(model_name)) not between 1 and 120
    ) then
    raise exception 'invalid_ai_tool_continuation_turn';
  end if;

  select * into v_run
  from public.ai_tool_continuation_runs run
  where run.id = p_run_id
  for update;
  if not found then raise exception 'ai_tool_continuation_run_not_found'; end if;
  if v_run.status not in ('running', 'completed') then
    raise exception 'ai_tool_continuation_run_closed';
  end if;

  select * into v_reservation
  from public.ai_budget_reservations reservation
  where reservation.user_id = v_run.user_id
    and reservation.operation = v_run.operation
    and reservation.idempotency_key = p_idempotency_key
    and reservation.trace_id = v_run.trace_id;
  if not found or v_reservation.status <> 'settled' then
    raise exception 'settled_ai_tool_continuation_reservation_required';
  end if;

  select * into v_receipt
  from public.ai_provider_execution_receipts receipt
  where receipt.reservation_id = v_reservation.id;
  if not found then
    raise exception 'ai_tool_continuation_receipt_required';
  end if;
  if p_attempted_models[cardinality(p_attempted_models)] <> v_receipt.model_name
    or v_receipt.thinking_level = 'unknown' then
    raise exception 'ai_tool_continuation_model_attribution_mismatch';
  end if;

  select
    coalesce(grounding.actual_query_count, 0),
    coalesce(grounding.actual_cost_micros, 0)
  into v_grounding_queries, v_grounding_cost
  from public.ai_grounding_budget_reservations grounding
  where grounding.reservation_id = v_reservation.id
    and grounding.status = 'settled';
  if not found then
    v_grounding_queries := 0;
    v_grounding_cost := 0;
  end if;
  v_digest := encode(digest(p_idempotency_key, 'sha256'), 'hex');

  select * into v_existing
  from public.ai_tool_continuation_turns turn_record
  where turn_record.run_id = p_run_id
    and turn_record.turn_number = p_turn_number
  for update;
  if found then
    if v_existing.reservation_id <> v_reservation.id
      or v_existing.idempotency_key_digest <> v_digest
      or v_existing.attempted_models <> p_attempted_models then
      raise exception 'ai_tool_continuation_turn_conflict';
    end if;
    return jsonb_build_object(
      'recorded', true,
      'idempotent', true,
      'turn_number', p_turn_number
    );
  end if;

  insert into public.ai_tool_continuation_turns (
    run_id,
    turn_number,
    reservation_id,
    idempotency_key_digest,
    attempted_models,
    settled_model,
    thinking_level,
    input_tokens,
    output_tokens,
    grounding_query_count,
    total_cost_micros
  ) values (
    p_run_id,
    p_turn_number,
    v_reservation.id,
    v_digest,
    p_attempted_models,
    v_receipt.model_name,
    v_receipt.thinking_level,
    v_receipt.input_tokens,
    v_receipt.output_tokens,
    v_grounding_queries,
    coalesce(v_reservation.actual_cost_micros, 0) + v_grounding_cost
  );
  return jsonb_build_object(
    'recorded', true,
    'idempotent', false,
    'turn_number', p_turn_number
  );
end;
$$;

create or replace function public.finalize_ai_tool_continuation_attribution(
  p_run_id uuid,
  p_total_input_tokens integer,
  p_total_output_tokens integer,
  p_total_grounding_query_count integer
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_run public.ai_tool_continuation_runs%rowtype;
  v_turn_count integer;
  v_min_turn integer;
  v_max_turn integer;
  v_input integer;
  v_output integer;
  v_grounding integer;
  v_cost bigint;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_total_input_tokens not between 0 and 1000000
    or p_total_output_tokens not between 0 and 1000000
    or p_total_grounding_query_count not between 0 and 100 then
    raise exception 'invalid_ai_tool_continuation_totals';
  end if;

  select * into v_run
  from public.ai_tool_continuation_runs run
  where run.id = p_run_id
  for update;
  if not found then raise exception 'ai_tool_continuation_run_not_found'; end if;

  select
    count(*)::integer,
    min(turn_record.turn_number),
    max(turn_record.turn_number),
    coalesce(sum(turn_record.input_tokens), 0)::integer,
    coalesce(sum(turn_record.output_tokens), 0)::integer,
    coalesce(sum(turn_record.grounding_query_count), 0)::integer,
    coalesce(sum(turn_record.total_cost_micros), 0)::bigint
  into
    v_turn_count,
    v_min_turn,
    v_max_turn,
    v_input,
    v_output,
    v_grounding,
    v_cost
  from public.ai_tool_continuation_turns turn_record
  where turn_record.run_id = p_run_id;

  if v_turn_count = 0
    or v_min_turn <> 0
    or v_max_turn <> v_turn_count - 1
    or v_input <> p_total_input_tokens
    or v_output <> p_total_output_tokens
    or v_grounding <> p_total_grounding_query_count then
    raise exception 'ai_tool_continuation_total_mismatch';
  end if;

  if v_run.status = 'completed' then
    if v_run.turn_count <> v_turn_count
      or v_run.total_input_tokens <> v_input
      or v_run.total_output_tokens <> v_output
      or v_run.total_grounding_query_count <> v_grounding
      or v_run.total_cost_micros <> v_cost then
      raise exception 'ai_tool_continuation_completion_conflict';
    end if;
    return jsonb_build_object(
      'completed', true,
      'idempotent', true,
      'turn_count', v_turn_count,
      'total_cost_micros', v_cost
    );
  end if;
  if v_run.status <> 'running' then
    raise exception 'ai_tool_continuation_run_closed';
  end if;

  update public.ai_tool_continuation_runs
  set status = 'completed',
      turn_count = v_turn_count,
      total_input_tokens = v_input,
      total_output_tokens = v_output,
      total_grounding_query_count = v_grounding,
      total_cost_micros = v_cost,
      completed_at = now()
  where id = p_run_id;
  return jsonb_build_object(
    'completed', true,
    'idempotent', false,
    'turn_count', v_turn_count,
    'total_cost_micros', v_cost
  );
end;
$$;

create or replace function public.fail_ai_tool_continuation_attribution(
  p_run_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_run public.ai_tool_continuation_runs%rowtype;
  v_turn_count integer;
  v_input integer;
  v_output integer;
  v_grounding integer;
  v_cost bigint;
  v_status text;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_reason not in (
    'timeout', 'cancelled', 'tool_failed', 'provider_failed',
    'attribution_failed'
  ) then
    raise exception 'invalid_ai_tool_continuation_failure_reason';
  end if;

  select * into v_run
  from public.ai_tool_continuation_runs run
  where run.id = p_run_id
  for update;
  if not found then raise exception 'ai_tool_continuation_run_not_found'; end if;
  if v_run.status = 'completed' then
    return jsonb_build_object('failed', false, 'reason', 'already_completed');
  end if;
  if v_run.status in ('failed', 'cancelled') then
    return jsonb_build_object('failed', true, 'idempotent', true);
  end if;

  select
    count(*)::integer,
    coalesce(sum(turn_record.input_tokens), 0)::integer,
    coalesce(sum(turn_record.output_tokens), 0)::integer,
    coalesce(sum(turn_record.grounding_query_count), 0)::integer,
    coalesce(sum(turn_record.total_cost_micros), 0)::bigint
  into v_turn_count, v_input, v_output, v_grounding, v_cost
  from public.ai_tool_continuation_turns turn_record
  where turn_record.run_id = p_run_id;
  v_status := case when p_reason = 'cancelled' then 'cancelled' else 'failed' end;

  update public.ai_tool_continuation_runs
  set status = v_status,
      turn_count = v_turn_count,
      total_input_tokens = v_input,
      total_output_tokens = v_output,
      total_grounding_query_count = v_grounding,
      total_cost_micros = v_cost,
      failure_reason = p_reason,
      completed_at = now()
  where id = p_run_id;
  return jsonb_build_object('failed', true, 'idempotent', false);
end;
$$;

create or replace function public.purge_expired_ai_tool_continuation_evidence()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_deleted integer;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  delete from public.ai_tool_continuation_runs run
  where run.retention_until <= now()
    and run.status <> 'running';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.start_ai_tool_continuation_attribution(
  uuid, text, text, uuid
) from public;
revoke all on function public.record_ai_tool_continuation_turn(
  uuid, integer, text, text[]
) from public;
revoke all on function public.finalize_ai_tool_continuation_attribution(
  uuid, integer, integer, integer
) from public;
revoke all on function public.fail_ai_tool_continuation_attribution(uuid, text)
  from public;
revoke all on function public.purge_expired_ai_tool_continuation_evidence()
  from public;

grant execute on function public.start_ai_tool_continuation_attribution(
  uuid, text, text, uuid
) to service_role;
grant execute on function public.record_ai_tool_continuation_turn(
  uuid, integer, text, text[]
) to service_role;
grant execute on function public.finalize_ai_tool_continuation_attribution(
  uuid, integer, integer, integer
) to service_role;
grant execute on function public.fail_ai_tool_continuation_attribution(
  uuid, text
) to service_role;
grant execute on function public.purge_expired_ai_tool_continuation_evidence()
  to service_role;

commit;
