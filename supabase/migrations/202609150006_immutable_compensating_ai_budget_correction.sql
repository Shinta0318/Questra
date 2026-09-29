begin;

alter table public.ai_budget_correction_requests
  add column if not exists compensates_request_id uuid references
    public.ai_budget_correction_requests(id) on delete restrict;

alter table public.ai_budget_correction_requests
  drop constraint if exists ai_budget_correction_requests_reason_code_check;
alter table public.ai_budget_correction_requests
  add constraint ai_budget_correction_requests_reason_code_check check (
    reason_code in (
      'provider_usage_correction', 'provider_refund',
      'duplicate_charge', 'manual_audit', 'compensating_correction'
    )
  ),
  add constraint ai_budget_correction_compensates_other_check check (
    compensates_request_id is null or compensates_request_id <> id
  );

alter table public.ai_budget_reconciliation_operator_events
  drop constraint if exists ai_budget_reconciliation_operator_events_reason_code_check;
alter table public.ai_budget_reconciliation_operator_events
  add constraint ai_budget_reconciliation_operator_events_reason_code_check check (
    reason_code in (
      'oldest_open_first', 'expired_claim_reclaimed', 'operator_released',
      'evidence_verified_no_change', 'reservation_released_no_execution',
      'duplicate_execution_no_change', 'false_positive',
      'correction_applied', 'evidence_unavailable',
      'provider_usage_correction', 'provider_refund', 'duplicate_charge',
      'manual_audit', 'compensating_correction',
      'evidence_verified', 'insufficient_evidence'
    )
  );

create unique index if not exists ai_budget_correction_one_compensation_idx
  on public.ai_budget_correction_requests (compensates_request_id)
  where compensates_request_id is not null;

create index if not exists ai_budget_correction_compensation_chain_idx
  on public.ai_budget_correction_requests (
    reservation_id, compensates_request_id, requested_at desc
  )
  where compensates_request_id is not null;

create or replace function public.request_compensating_ai_budget_correction(
  p_applied_request_id uuid,
  p_operator_id uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_original public.ai_budget_correction_requests%rowtype;
  v_existing public.ai_budget_correction_requests%rowtype;
  v_case public.ai_budget_reconciliation_cases%rowtype;
  v_reservation public.ai_budget_reservations%rowtype;
  v_request_id uuid;
begin
  perform public.assert_ai_reconciliation_operator(p_operator_id, 'reviewer');
  if char_length(p_idempotency_key) not between 8 and 120 then
    raise exception 'invalid_budget_correction_idempotency_key';
  end if;

  select * into v_original
  from public.ai_budget_correction_requests request
  where request.id = p_applied_request_id
  for update;
  if not found then
    raise exception 'budget_correction_request_not_found';
  end if;
  if v_original.status <> 'applied' then
    raise exception 'applied_budget_correction_required';
  end if;

  select * into v_case
  from public.ai_budget_reconciliation_cases review
  where review.reservation_id = v_original.reservation_id
  for update;
  if not found then
    raise exception 'reconciliation_case_not_found';
  end if;
  if v_case.status <> 'open'
    or v_case.claimed_by <> p_operator_id
    or v_case.claim_expires_at <= now() then
    raise exception 'active_operator_claim_required';
  end if;

  select * into v_reservation
  from public.ai_budget_reservations reservation
  where reservation.id = v_original.reservation_id
  for update;
  if not found then
    raise exception 'ai_reservation_not_found';
  end if;
  if v_reservation.status <> 'settled'
    or v_reservation.model_name <> v_original.corrected_model_name
    or v_reservation.actual_input_tokens <> v_original.corrected_input_tokens
    or v_reservation.actual_output_tokens <> v_original.corrected_output_tokens
    or v_reservation.actual_cost_micros <> v_original.corrected_cost_micros then
    raise exception 'budget_compensation_stale_snapshot';
  end if;

  select * into v_existing
  from public.ai_budget_correction_requests request
  where request.reservation_id = v_original.reservation_id
    and request.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.requested_by <> p_operator_id
      or v_existing.compensates_request_id is distinct from v_original.id then
      raise exception 'budget_correction_idempotency_conflict';
    end if;
    return jsonb_build_object(
      'requested', true,
      'idempotent', true,
      'request_id', v_existing.id,
      'status', v_existing.status,
      'compensates_request_id', v_original.id
    );
  end if;

  select * into v_existing
  from public.ai_budget_correction_requests request
  where request.compensates_request_id = v_original.id;
  if found then
    raise exception 'budget_correction_already_compensated';
  end if;

  insert into public.ai_budget_correction_requests (
    reservation_id,
    idempotency_key,
    reason_code,
    requested_by,
    before_model_name,
    before_input_tokens,
    before_output_tokens,
    before_cost_micros,
    corrected_model_name,
    corrected_input_tokens,
    corrected_output_tokens,
    corrected_cost_micros,
    cost_delta_micros,
    compensates_request_id
  ) values (
    v_original.reservation_id,
    p_idempotency_key,
    'compensating_correction',
    p_operator_id,
    v_reservation.model_name,
    v_reservation.actual_input_tokens,
    v_reservation.actual_output_tokens,
    v_reservation.actual_cost_micros,
    v_original.before_model_name,
    v_original.before_input_tokens,
    v_original.before_output_tokens,
    v_original.before_cost_micros,
    v_original.before_cost_micros - v_reservation.actual_cost_micros,
    v_original.id
  ) returning id into v_request_id;

  insert into public.ai_budget_reconciliation_operator_events (
    reservation_id, operator_id, action, reason_code
  ) values (
    v_original.reservation_id,
    p_operator_id,
    'correction_requested',
    'compensating_correction'
  );

  return jsonb_build_object(
    'requested', true,
    'idempotent', false,
    'request_id', v_request_id,
    'status', 'pending_approval',
    'compensates_request_id', v_original.id,
    'cost_delta_micros',
      v_original.before_cost_micros - v_reservation.actual_cost_micros
  );
end;
$$;

create or replace function public.request_my_compensating_ai_budget_correction(
  p_applied_request_id uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return public.request_compensating_ai_budget_correction(
    p_applied_request_id,
    public.current_ai_reconciliation_operator('reviewer'),
    p_idempotency_key
  );
end;
$$;

revoke all on function public.request_compensating_ai_budget_correction(
  uuid, uuid, text
) from public, anon, authenticated, service_role;
revoke all on function public.request_my_compensating_ai_budget_correction(
  uuid, text
) from public, anon;
grant execute on function public.request_my_compensating_ai_budget_correction(
  uuid, text
) to authenticated;

comment on column public.ai_budget_correction_requests.compensates_request_id is
  'Applied correction reversed by this immutable, separately approved request.';
comment on function public.request_my_compensating_ai_budget_correction(
  uuid, text
) is
  'Creates an auth-bound pending compensation without mutating counters.';

commit;
