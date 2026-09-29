begin;

alter table public.ai_budget_reservations
  add column if not exists receipt_nonce_hash text,
  add column if not exists allowed_model_names text[],
  add column if not exists model_route_digest text;

alter table public.ai_budget_reservations
  drop constraint if exists ai_budget_receipt_nonce_hash_check,
  add constraint ai_budget_receipt_nonce_hash_check check (
    receipt_nonce_hash is null or receipt_nonce_hash ~ '^[0-9a-f]{64}$'
  ),
  drop constraint if exists ai_budget_allowed_model_names_check,
  add constraint ai_budget_allowed_model_names_check check (
    allowed_model_names is null
    or cardinality(allowed_model_names) between 1 and 4
  ),
  drop constraint if exists ai_budget_model_route_digest_check,
  add constraint ai_budget_model_route_digest_check check (
    model_route_digest is null or model_route_digest ~ '^[0-9a-f]{64}$'
  );

alter table public.ai_provider_execution_receipts
  add column if not exists operation text,
  add column if not exists model_route_digest text,
  add column if not exists request_nonce_verified boolean not null default false;

alter table public.ai_provider_execution_receipts
  drop constraint if exists ai_provider_receipt_operation_check,
  add constraint ai_provider_receipt_operation_check check (
    operation is null or operation in (
      'arc_consultation', 'quest_planning', 'basic_mission_planning',
      'mission_redesign', 'detailed_progress_review'
    )
  ),
  drop constraint if exists ai_provider_receipt_model_route_digest_check,
  add constraint ai_provider_receipt_model_route_digest_check check (
    model_route_digest is null or model_route_digest ~ '^[0-9a-f]{64}$'
  );

create or replace function public.reserve_ai_usage_budget_v3(
  p_user_id uuid,
  p_operation text,
  p_idempotency_key text,
  p_provider text,
  p_model_names text[],
  p_estimated_input_tokens integer,
  p_max_output_tokens integer,
  p_trace_id uuid,
  p_receipt_nonce_hash text,
  p_model_route_digest text,
  p_abuse_key_hash text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
  v_reservation public.ai_budget_reservations%rowtype;
  v_models text[];
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_receipt_nonce_hash !~ '^[0-9a-f]{64}$'
    or p_model_route_digest !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_ai_receipt_binding';
  end if;

  select array_agg(candidate order by candidate) into v_models
  from (
    select distinct btrim(input.model_name) as candidate
    from unnest(p_model_names) as input(model_name)
  ) normalized;
  if coalesce(cardinality(v_models), 0) not between 1 and 4 then
    raise exception 'invalid_ai_model_candidates';
  end if;

  v_result := public.reserve_ai_usage_budget_v2(
    p_user_id,
    p_operation,
    p_idempotency_key,
    p_provider,
    v_models,
    p_estimated_input_tokens,
    p_max_output_tokens,
    p_trace_id,
    p_abuse_key_hash
  );
  if coalesce((v_result ->> 'allowed')::boolean, false) is false then
    return v_result;
  end if;

  select * into v_reservation
  from public.ai_budget_reservations
  where id = (v_result ->> 'reservation_id')::uuid
  for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;

  if v_reservation.receipt_nonce_hash is not null
    and (
      v_reservation.receipt_nonce_hash <> p_receipt_nonce_hash
      or v_reservation.model_route_digest <> p_model_route_digest
      or v_reservation.allowed_model_names <> v_models
    ) then
    raise exception 'ai_receipt_binding_conflict';
  end if;

  update public.ai_budget_reservations
  set receipt_nonce_hash = p_receipt_nonce_hash,
      allowed_model_names = v_models,
      model_route_digest = p_model_route_digest
  where id = v_reservation.id
    and receipt_nonce_hash is null;

  return v_result || jsonb_build_object(
    'receipt_binding', true,
    'model_route_digest', p_model_route_digest
  );
end;
$$;

create or replace function public.open_ai_receipt_binding_conflict(
  p_reservation_id uuid,
  p_reason text,
  p_evidence_digest text default null
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reservation public.ai_budget_reservations%rowtype;
begin
  select * into v_reservation
  from public.ai_budget_reservations
  where id = p_reservation_id
  for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;
  if p_reason not in (
    'receipt_nonce_mismatch', 'receipt_trace_mismatch',
    'receipt_operation_mismatch', 'receipt_model_route_mismatch',
    'receipt_model_not_allowed', 'provider_interaction_replay'
  ) then
    raise exception 'invalid_ai_receipt_conflict_reason';
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
    p_evidence_digest,
    'evidence_conflict',
    p_reason
  );
end;
$$;

create or replace function public.record_ai_provider_execution_receipt_v4(
  p_reservation_id uuid,
  p_provider_interaction_id text,
  p_model_name text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_finish_reason text,
  p_trace_id uuid,
  p_grounding_query_count integer,
  p_thinking_level text,
  p_operation text,
  p_model_route_digest text,
  p_receipt_nonce text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reservation public.ai_budget_reservations%rowtype;
  v_replayed public.ai_provider_execution_receipts%rowtype;
  v_result jsonb;
  v_nonce_hash text;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_receipt_nonce !~ '^[0-9a-f]{64}$'
    or p_model_route_digest !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_ai_receipt_binding';
  end if;

  select * into v_reservation
  from public.ai_budget_reservations
  where id = p_reservation_id
  for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;

  v_nonce_hash := encode(digest(p_receipt_nonce, 'sha256'), 'hex');
  if v_reservation.receipt_nonce_hash is null
    or v_reservation.receipt_nonce_hash <> v_nonce_hash then
    perform public.open_ai_receipt_binding_conflict(
      p_reservation_id, 'receipt_nonce_mismatch'
    );
    return jsonb_build_object(
      'recorded', false,
      'reason', 'receipt_nonce_mismatch',
      'operator_review', true
    );
  end if;
  if v_reservation.trace_id <> p_trace_id then
    perform public.open_ai_receipt_binding_conflict(
      p_reservation_id, 'receipt_trace_mismatch'
    );
    return jsonb_build_object(
      'recorded', false,
      'reason', 'receipt_trace_mismatch',
      'operator_review', true
    );
  end if;
  if v_reservation.operation <> p_operation then
    perform public.open_ai_receipt_binding_conflict(
      p_reservation_id, 'receipt_operation_mismatch'
    );
    return jsonb_build_object(
      'recorded', false,
      'reason', 'receipt_operation_mismatch',
      'operator_review', true
    );
  end if;
  if v_reservation.model_route_digest <> p_model_route_digest then
    perform public.open_ai_receipt_binding_conflict(
      p_reservation_id, 'receipt_model_route_mismatch'
    );
    return jsonb_build_object(
      'recorded', false,
      'reason', 'receipt_model_route_mismatch',
      'operator_review', true
    );
  end if;
  if not (p_model_name = any(v_reservation.allowed_model_names)) then
    perform public.open_ai_receipt_binding_conflict(
      p_reservation_id, 'receipt_model_not_allowed'
    );
    return jsonb_build_object(
      'recorded', false,
      'reason', 'receipt_model_not_allowed',
      'operator_review', true
    );
  end if;

  if p_provider_interaction_id is not null then
    select * into v_replayed
    from public.ai_provider_execution_receipts
    where provider = v_reservation.provider
      and provider_interaction_id = p_provider_interaction_id
      and reservation_id <> p_reservation_id
    limit 1;
    if found then
      perform public.open_ai_receipt_binding_conflict(
        p_reservation_id,
        'provider_interaction_replay',
        v_replayed.evidence_digest
      );
      return jsonb_build_object(
        'recorded', false,
        'reason', 'provider_interaction_replay',
        'operator_review', true
      );
    end if;
  end if;

  begin
    v_result := public.record_ai_provider_execution_receipt_v3(
      p_reservation_id,
      p_provider_interaction_id,
      p_model_name,
      p_input_tokens,
      p_output_tokens,
      p_finish_reason,
      p_trace_id,
      p_grounding_query_count,
      p_thinking_level
    );
  exception when unique_violation then
    perform public.open_ai_receipt_binding_conflict(
      p_reservation_id, 'provider_interaction_replay'
    );
    return jsonb_build_object(
      'recorded', false,
      'reason', 'provider_interaction_replay',
      'operator_review', true
    );
  end;
  if coalesce((v_result ->> 'recorded')::boolean, false) is false then
    return v_result;
  end if;

  update public.ai_provider_execution_receipts
  set operation = p_operation,
      model_route_digest = p_model_route_digest,
      request_nonce_verified = true
  where reservation_id = p_reservation_id
    and (operation is null or operation = p_operation)
    and (model_route_digest is null or model_route_digest = p_model_route_digest);
  if not found then
    perform public.open_ai_receipt_binding_conflict(
      p_reservation_id, 'receipt_model_route_mismatch'
    );
    return jsonb_build_object(
      'recorded', false,
      'reason', 'receipt_binding_conflict',
      'operator_review', true
    );
  end if;

  return v_result || jsonb_build_object('request_nonce_verified', true);
end;
$$;

create or replace function public.require_ai_receipt_request_binding()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_receipt public.ai_provider_execution_receipts%rowtype;
begin
  if old.status = 'reserved'
    and new.status = 'settled'
    and new.receipt_nonce_hash is not null then
    select * into v_receipt
    from public.ai_provider_execution_receipts
    where reservation_id = new.id;
    if not found
      or v_receipt.request_nonce_verified is false
      or v_receipt.operation is distinct from new.operation
      or v_receipt.model_route_digest is distinct from new.model_route_digest then
      raise exception 'ai_provider_request_binding_required';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists require_ai_receipt_request_binding
  on public.ai_budget_reservations;
create trigger require_ai_receipt_request_binding
before update of status on public.ai_budget_reservations
for each row execute function public.require_ai_receipt_request_binding();

revoke all on function public.reserve_ai_usage_budget_v3(
  uuid, text, text, text, text[], integer, integer, uuid, text, text, text
) from public;
revoke all on function public.open_ai_receipt_binding_conflict(
  uuid, text, text
) from public;
revoke all on function public.record_ai_provider_execution_receipt_v4(
  uuid, text, text, integer, integer, text, uuid, integer, text, text,
  text, text
) from public;
revoke all on function public.require_ai_receipt_request_binding()
  from public;

grant execute on function public.reserve_ai_usage_budget_v3(
  uuid, text, text, text, text[], integer, integer, uuid, text, text, text
) to service_role;
grant execute on function public.record_ai_provider_execution_receipt_v4(
  uuid, text, text, integer, integer, text, uuid, integer, text, text,
  text, text
) to service_role;

commit;
