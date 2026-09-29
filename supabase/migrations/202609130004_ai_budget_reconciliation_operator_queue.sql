begin;

create table if not exists public.ai_budget_reconciliation_operators (
  id uuid primary key default gen_random_uuid(),
  operator_key text not null unique check (
    operator_key ~ '^[a-z0-9][a-z0-9._-]{2,63}$'
  ),
  operator_role text not null check (operator_role in ('reviewer', 'approver')),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  disabled_at timestamptz,
  check (
    (enabled and disabled_at is null)
    or (not enabled and disabled_at is not null)
  )
);

alter table public.ai_budget_reconciliation_cases
  add column if not exists claimed_by uuid references
    public.ai_budget_reconciliation_operators(id) on delete restrict,
  add column if not exists claimed_at timestamptz,
  add column if not exists claim_expires_at timestamptz,
  add column if not exists resolution_code text,
  add column if not exists resolved_by uuid references
    public.ai_budget_reconciliation_operators(id) on delete restrict,
  add column if not exists updated_at timestamptz not null default now();

update public.ai_budget_reconciliation_cases
set resolution_code = case
      when status = 'resolved' then 'automated_reconciliation'
      when status = 'dismissed' then 'legacy_dismissal_no_charge_change'
      else null
    end,
    resolved_at = case
      when status = 'open' then null
      else coalesce(resolved_at, opened_at)
    end,
    resolved_by = null,
    claimed_by = null,
    claimed_at = null,
    claim_expires_at = null,
    resolution_note = null,
    updated_at = now();

alter table public.ai_budget_reconciliation_cases
  add constraint ai_budget_reconciliation_case_claim_check check (
    (
      claimed_by is null
      and claimed_at is null
      and claim_expires_at is null
    ) or (
      claimed_by is not null
      and claimed_at is not null
      and claim_expires_at > claimed_at
    )
  ),
  add constraint ai_budget_reconciliation_case_resolution_check check (
    (
      status = 'open'
      and resolved_at is null
      and resolution_code is null
      and resolved_by is null
    ) or (
      status in ('resolved', 'dismissed')
      and resolved_at is not null
      and resolution_code in (
        'automated_reconciliation',
        'legacy_dismissal_no_charge_change',
        'evidence_verified_no_change',
        'reservation_released_no_execution',
        'duplicate_execution_no_change',
        'false_positive',
        'correction_applied',
        'evidence_unavailable'
      )
    )
  ),
  add constraint ai_budget_reconciliation_case_note_empty_check check (
    resolution_note is null
  );

create index if not exists ai_budget_reconciliation_open_claim_idx
  on public.ai_budget_reconciliation_cases (opened_at, claim_expires_at)
  where status = 'open';

create table if not exists public.ai_budget_reconciliation_operator_events (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.ai_budget_reservations(id)
    on delete cascade,
  operator_id uuid not null references
    public.ai_budget_reconciliation_operators(id) on delete restrict,
  action text not null check (action in (
    'claimed', 'claim_released', 'resolved', 'dismissed',
    'correction_requested', 'correction_approved',
    'correction_rejected', 'correction_applied'
  )),
  reason_code text not null check (reason_code in (
    'oldest_open_first', 'expired_claim_reclaimed', 'operator_released',
    'evidence_verified_no_change', 'reservation_released_no_execution',
    'duplicate_execution_no_change', 'false_positive',
    'correction_applied', 'evidence_unavailable',
    'provider_usage_correction', 'provider_refund', 'duplicate_charge',
    'manual_audit', 'evidence_verified', 'insufficient_evidence'
  )),
  claim_expires_at timestamptz,
  created_at timestamptz not null default now(),
  retention_until timestamptz not null default (now() + interval '730 days')
);

create index if not exists ai_budget_operator_events_reservation_idx
  on public.ai_budget_reconciliation_operator_events (
    reservation_id, created_at desc
  );
create index if not exists ai_budget_operator_events_retention_idx
  on public.ai_budget_reconciliation_operator_events (retention_until);

create table if not exists public.ai_budget_correction_requests (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.ai_budget_reservations(id)
    on delete cascade,
  idempotency_key text not null check (
    char_length(idempotency_key) between 8 and 120
  ),
  reason_code text not null check (reason_code in (
    'provider_usage_correction', 'provider_refund',
    'duplicate_charge', 'manual_audit'
  )),
  status text not null default 'pending_approval' check (status in (
    'pending_approval', 'approved', 'rejected', 'applied'
  )),
  requested_by uuid not null references
    public.ai_budget_reconciliation_operators(id) on delete restrict,
  requested_at timestamptz not null default now(),
  before_model_name text not null check (
    char_length(before_model_name) between 1 and 120
  ),
  before_input_tokens integer not null check (
    before_input_tokens between 0 and 200000
  ),
  before_output_tokens integer not null check (
    before_output_tokens between 0 and 200000
  ),
  before_cost_micros bigint not null check (before_cost_micros >= 0),
  corrected_model_name text not null check (
    char_length(corrected_model_name) between 1 and 120
  ),
  corrected_input_tokens integer not null check (
    corrected_input_tokens between 0 and 200000
  ),
  corrected_output_tokens integer not null check (
    corrected_output_tokens between 0 and 200000
  ),
  corrected_cost_micros bigint not null check (corrected_cost_micros >= 0),
  cost_delta_micros bigint not null,
  approved_by uuid references public.ai_budget_reconciliation_operators(id)
    on delete restrict,
  approval_reason_code text check (
    approval_reason_code is null
    or approval_reason_code in ('evidence_verified', 'insufficient_evidence')
  ),
  approved_at timestamptz,
  applied_by uuid references public.ai_budget_reconciliation_operators(id)
    on delete restrict,
  applied_at timestamptz,
  retention_until timestamptz not null default (now() + interval '730 days'),
  unique (reservation_id, idempotency_key),
  check (
    corrected_model_name <> before_model_name
    or corrected_input_tokens <> before_input_tokens
    or corrected_output_tokens <> before_output_tokens
    or corrected_cost_micros <> before_cost_micros
  ),
  check (cost_delta_micros = corrected_cost_micros - before_cost_micros),
  check (approved_by is null or approved_by <> requested_by),
  check (
    (
      status = 'pending_approval'
      and approved_by is null
      and approval_reason_code is null
      and approved_at is null
      and applied_by is null
      and applied_at is null
    ) or (
      status = 'approved'
      and approved_by is not null
      and approval_reason_code = 'evidence_verified'
      and approved_at is not null
      and applied_by is null
      and applied_at is null
    ) or (
      status = 'rejected'
      and approved_by is not null
      and approval_reason_code = 'insufficient_evidence'
      and approved_at is not null
      and applied_by is null
      and applied_at is null
    ) or (
      status = 'applied'
      and approved_by is not null
      and approval_reason_code = 'evidence_verified'
      and approved_at is not null
      and applied_by is not null
      and applied_at is not null
    )
  )
);

create unique index if not exists ai_budget_correction_one_active_idx
  on public.ai_budget_correction_requests (reservation_id)
  where status in ('pending_approval', 'approved');
create index if not exists ai_budget_correction_retention_idx
  on public.ai_budget_correction_requests (retention_until)
  where status in ('rejected', 'applied');

alter table public.ai_budget_reconciliation_operators enable row level security;
alter table public.ai_budget_reconciliation_operator_events enable row level security;
alter table public.ai_budget_correction_requests enable row level security;

revoke all on public.ai_budget_reconciliation_operators
  from public, anon, authenticated;
revoke all on public.ai_budget_reconciliation_operator_events
  from public, anon, authenticated;
revoke all on public.ai_budget_correction_requests
  from public, anon, authenticated;
revoke all on public.ai_budget_reconciliation_cases
  from anon, authenticated;
revoke all on public.ai_provider_execution_receipts
  from anon, authenticated;
revoke all on public.ai_budget_reconciliation_attempts
  from anon, authenticated;

create or replace function public.normalize_ai_reconciliation_case()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_legacy_note text := new.resolution_note;
begin
  new.updated_at := now();
  new.resolution_note := null;
  if new.status = 'open' then
    new.resolved_at := null;
    new.resolution_code := null;
    new.resolved_by := null;
    if tg_op = 'INSERT' or old.status <> 'open' then
      new.claimed_by := null;
      new.claimed_at := null;
      new.claim_expires_at := null;
    end if;
  else
    new.resolved_at := coalesce(new.resolved_at, now());
    if new.resolution_code is null then
      new.resolution_code := case v_legacy_note
        when 'matching settlement verified from provider receipt'
          then 'automated_reconciliation'
        when 'reservation settled from provider receipt'
          then 'automated_reconciliation'
        else 'automated_reconciliation'
      end;
    end if;
    new.claimed_by := null;
    new.claimed_at := null;
    new.claim_expires_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists normalize_ai_reconciliation_case
  on public.ai_budget_reconciliation_cases;
create trigger normalize_ai_reconciliation_case
before insert or update on public.ai_budget_reconciliation_cases
for each row execute function public.normalize_ai_reconciliation_case();

create or replace function public.assert_ai_reconciliation_operator(
  p_operator_id uuid,
  p_required_role text default null
) returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role text;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_required_role is not null
    and p_required_role not in ('reviewer', 'approver') then
    raise exception 'invalid_operator_role_requirement';
  end if;
  select operator_role into v_role
  from public.ai_budget_reconciliation_operators
  where id = p_operator_id
    and enabled;
  if not found then raise exception 'reconciliation_operator_required'; end if;
  if p_required_role = 'approver' and v_role <> 'approver' then
    raise exception 'reconciliation_approver_required';
  end if;
  return v_role;
end;
$$;

create or replace function public.claim_ai_budget_reconciliation_cases(
  p_operator_id uuid,
  p_limit integer default 20,
  p_lease interval default interval '30 minutes'
) returns table (
  reservation_id uuid,
  case_reason text,
  opened_at timestamptz,
  claim_expires_at timestamptz,
  receipt_present boolean,
  reservation_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.assert_ai_reconciliation_operator(p_operator_id);
  if p_limit not between 1 and 100
    or p_lease < interval '5 minutes'
    or p_lease > interval '2 hours' then
    raise exception 'invalid_reconciliation_claim_bounds';
  end if;

  return query
  with candidates as (
    select review.reservation_id,
           (review.claimed_by is not null) as reclaimed
    from public.ai_budget_reconciliation_cases review
    where review.status = 'open'
      and (
        review.claimed_by is null
        or review.claim_expires_at <= now()
      )
    order by review.opened_at, review.reservation_id
    for update skip locked
    limit p_limit
  ), claimed as (
    update public.ai_budget_reconciliation_cases review
    set claimed_by = p_operator_id,
        claimed_at = now(),
        claim_expires_at = now() + p_lease,
        updated_at = now()
    from candidates
    where review.reservation_id = candidates.reservation_id
    returning review.reservation_id,
              review.reason,
              review.opened_at,
              review.claim_expires_at,
              candidates.reclaimed
  ), audited as (
    insert into public.ai_budget_reconciliation_operator_events (
      reservation_id, operator_id, action, reason_code, claim_expires_at
    )
    select claimed.reservation_id,
           p_operator_id,
           'claimed',
           case when claimed.reclaimed
             then 'expired_claim_reclaimed'
             else 'oldest_open_first'
           end,
           claimed.claim_expires_at
    from claimed
    returning public.ai_budget_reconciliation_operator_events.reservation_id
  )
  select claimed.reservation_id,
         claimed.reason,
         claimed.opened_at,
         claimed.claim_expires_at,
         (receipt.reservation_id is not null),
         reservation.status
  from claimed
  join audited
    on audited.reservation_id = claimed.reservation_id
  join public.ai_budget_reservations reservation
    on reservation.id = claimed.reservation_id
  left join public.ai_provider_execution_receipts receipt
    on receipt.reservation_id = claimed.reservation_id
  order by claimed.opened_at, claimed.reservation_id;
end;
$$;

create or replace function public.release_ai_budget_reconciliation_claim(
  p_reservation_id uuid,
  p_operator_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.assert_ai_reconciliation_operator(p_operator_id);
  perform 1
  from public.ai_budget_reconciliation_cases review
  where review.reservation_id = p_reservation_id
    and review.status = 'open'
    and review.claimed_by = p_operator_id
  for update;
  if not found then raise exception 'active_operator_claim_required'; end if;

  update public.ai_budget_reconciliation_cases
  set claimed_by = null,
      claimed_at = null,
      claim_expires_at = null,
      updated_at = now()
  where reservation_id = p_reservation_id;
  insert into public.ai_budget_reconciliation_operator_events (
    reservation_id, operator_id, action, reason_code
  ) values (
    p_reservation_id, p_operator_id, 'claim_released', 'operator_released'
  );
  return jsonb_build_object('released', true);
end;
$$;

create or replace function public.request_ai_budget_correction(
  p_reservation_id uuid,
  p_operator_id uuid,
  p_corrected_model_name text,
  p_corrected_input_tokens integer,
  p_corrected_output_tokens integer,
  p_reason_code text,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reservation public.ai_budget_reservations%rowtype;
  v_case public.ai_budget_reconciliation_cases%rowtype;
  v_existing public.ai_budget_correction_requests%rowtype;
  v_corrected_cost bigint;
  v_request_id uuid;
begin
  perform public.assert_ai_reconciliation_operator(p_operator_id);
  if p_reason_code not in (
    'provider_usage_correction', 'provider_refund',
    'duplicate_charge', 'manual_audit'
  ) then raise exception 'invalid_budget_correction_reason'; end if;
  if char_length(p_idempotency_key) not between 8 and 120
    or char_length(p_corrected_model_name) not between 1 and 120
    or p_corrected_input_tokens not between 0 and 200000
    or p_corrected_output_tokens not between 0 and 200000 then
    raise exception 'invalid_budget_correction_request';
  end if;

  select * into v_case
  from public.ai_budget_reconciliation_cases review
  where review.reservation_id = p_reservation_id
  for update;
  if not found then raise exception 'reconciliation_case_not_found'; end if;
  if v_case.status <> 'open'
    or v_case.claimed_by <> p_operator_id
    or v_case.claim_expires_at <= now() then
    raise exception 'active_operator_claim_required';
  end if;

  select * into v_reservation
  from public.ai_budget_reservations reservation
  where reservation.id = p_reservation_id
  for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;
  if v_reservation.status <> 'settled' then
    raise exception 'settled_reservation_required_for_correction';
  end if;

  select * into v_existing
  from public.ai_budget_correction_requests request
  where request.reservation_id = p_reservation_id
    and request.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.requested_by <> p_operator_id
      or v_existing.corrected_model_name <> p_corrected_model_name
      or v_existing.corrected_input_tokens <> p_corrected_input_tokens
      or v_existing.corrected_output_tokens <> p_corrected_output_tokens
      or v_existing.reason_code <> p_reason_code then
      raise exception 'budget_correction_idempotency_conflict';
    end if;
    return jsonb_build_object(
      'requested', true,
      'idempotent', true,
      'request_id', v_existing.id,
      'status', v_existing.status
    );
  end if;

  v_corrected_cost := public.ai_token_cost_micros_at(
    v_reservation.provider,
    p_corrected_model_name,
    p_corrected_input_tokens,
    p_corrected_output_tokens,
    v_reservation.pricing_effective_at
  );
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
    cost_delta_micros
  ) values (
    p_reservation_id,
    p_idempotency_key,
    p_reason_code,
    p_operator_id,
    v_reservation.model_name,
    v_reservation.actual_input_tokens,
    v_reservation.actual_output_tokens,
    v_reservation.actual_cost_micros,
    p_corrected_model_name,
    p_corrected_input_tokens,
    p_corrected_output_tokens,
    v_corrected_cost,
    v_corrected_cost - v_reservation.actual_cost_micros
  ) returning id into v_request_id;

  insert into public.ai_budget_reconciliation_operator_events (
    reservation_id, operator_id, action, reason_code
  ) values (
    p_reservation_id, p_operator_id, 'correction_requested', p_reason_code
  );
  return jsonb_build_object(
    'requested', true,
    'idempotent', false,
    'request_id', v_request_id,
    'status', 'pending_approval',
    'cost_delta_micros', v_corrected_cost - v_reservation.actual_cost_micros
  );
end;
$$;

create or replace function public.review_ai_budget_correction(
  p_request_id uuid,
  p_operator_id uuid,
  p_decision text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_request public.ai_budget_correction_requests%rowtype;
  v_status text;
  v_reason text;
begin
  perform public.assert_ai_reconciliation_operator(p_operator_id, 'approver');
  if p_decision not in ('approve', 'reject') then
    raise exception 'invalid_budget_correction_decision';
  end if;
  select * into v_request
  from public.ai_budget_correction_requests request
  where request.id = p_request_id
  for update;
  if not found then raise exception 'budget_correction_request_not_found'; end if;
  if v_request.requested_by = p_operator_id then
    raise exception 'budget_correction_self_approval_forbidden';
  end if;
  if v_request.status <> 'pending_approval' then
    if (p_decision = 'approve' and v_request.status in ('approved', 'applied'))
      or (p_decision = 'reject' and v_request.status = 'rejected') then
      return jsonb_build_object(
        'reviewed', true,
        'idempotent', true,
        'status', v_request.status
      );
    end if;
    raise exception 'budget_correction_review_conflict';
  end if;

  v_status := case p_decision when 'approve' then 'approved' else 'rejected' end;
  v_reason := case p_decision
    when 'approve' then 'evidence_verified'
    else 'insufficient_evidence'
  end;
  update public.ai_budget_correction_requests
  set status = v_status,
      approved_by = p_operator_id,
      approval_reason_code = v_reason,
      approved_at = now()
  where id = p_request_id;
  insert into public.ai_budget_reconciliation_operator_events (
    reservation_id, operator_id, action, reason_code
  ) values (
    v_request.reservation_id,
    p_operator_id,
    case p_decision
      when 'approve' then 'correction_approved'
      else 'correction_rejected'
    end,
    v_reason
  );
  return jsonb_build_object(
    'reviewed', true,
    'idempotent', false,
    'status', v_status
  );
end;
$$;

create or replace function public.apply_ai_budget_correction(
  p_request_id uuid,
  p_operator_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_request public.ai_budget_correction_requests%rowtype;
  v_reservation public.ai_budget_reservations%rowtype;
  v_rate public.ai_model_cost_rates%rowtype;
begin
  perform public.assert_ai_reconciliation_operator(p_operator_id, 'approver');
  select * into v_request
  from public.ai_budget_correction_requests request
  where request.id = p_request_id
  for update;
  if not found then raise exception 'budget_correction_request_not_found'; end if;
  if v_request.status = 'applied' then
    return jsonb_build_object(
      'applied', true,
      'idempotent', true,
      'cost_delta_micros', v_request.cost_delta_micros
    );
  end if;
  if v_request.status <> 'approved'
    or v_request.approved_by <> p_operator_id then
    raise exception 'approved_budget_correction_required';
  end if;

  select * into v_reservation
  from public.ai_budget_reservations reservation
  where reservation.id = v_request.reservation_id
  for update;
  if not found then raise exception 'ai_reservation_not_found'; end if;
  if v_reservation.status <> 'settled'
    or v_reservation.model_name <> v_request.before_model_name
    or v_reservation.actual_input_tokens <> v_request.before_input_tokens
    or v_reservation.actual_output_tokens <> v_request.before_output_tokens
    or v_reservation.actual_cost_micros <> v_request.before_cost_micros then
    raise exception 'budget_correction_stale_snapshot';
  end if;

  select * into v_rate
  from public.ai_model_cost_rates rate
  where rate.provider = v_reservation.provider
    and rate.model_name = v_request.corrected_model_name
    and rate.effective_from <= v_reservation.pricing_effective_at
    and (
      rate.valid_until is null
      or rate.valid_until > v_reservation.pricing_effective_at
    )
  order by rate.effective_from desc
  limit 1;
  if not found then raise exception 'ai_model_cost_rate_missing_at_reservation'; end if;

  update public.ai_usage_counters counter
  set actual_cost_micros = counter.actual_cost_micros
        + v_request.cost_delta_micros,
      updated_at = now()
  where counter.user_id = v_reservation.user_id
    and counter.operation = v_reservation.operation
    and counter.period_start = v_reservation.period_start
    and counter.actual_cost_micros + v_request.cost_delta_micros >= 0;
  if not found then raise exception 'ai_usage_counter_correction_conflict'; end if;

  update public.ai_budget_reservations
  set model_name = v_request.corrected_model_name,
      actual_input_tokens = v_request.corrected_input_tokens,
      actual_output_tokens = v_request.corrected_output_tokens,
      actual_cost_micros = v_request.corrected_cost_micros,
      actual_rate_effective_from = v_rate.effective_from,
      actual_input_rate_micros = v_rate.input_micros_per_million_tokens,
      actual_output_rate_micros = v_rate.output_micros_per_million_tokens,
      actual_pricing_source_uri = v_rate.source_uri
  where id = v_request.reservation_id;
  update public.ai_budget_correction_requests
  set status = 'applied',
      applied_by = p_operator_id,
      applied_at = now()
  where id = p_request_id;
  insert into public.ai_budget_reconciliation_operator_events (
    reservation_id, operator_id, action, reason_code
  ) values (
    v_request.reservation_id,
    p_operator_id,
    'correction_applied',
    'correction_applied'
  );
  return jsonb_build_object(
    'applied', true,
    'idempotent', false,
    'cost_delta_micros', v_request.cost_delta_micros,
    'corrected_cost_micros', v_request.corrected_cost_micros
  );
end;
$$;

create or replace function public.resolve_ai_budget_reconciliation_case(
  p_reservation_id uuid,
  p_operator_id uuid,
  p_disposition text,
  p_resolution_code text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_case public.ai_budget_reconciliation_cases%rowtype;
  v_reservation_status text;
begin
  perform public.assert_ai_reconciliation_operator(p_operator_id);
  if p_disposition not in ('resolved', 'dismissed') then
    raise exception 'invalid_reconciliation_disposition';
  end if;
  if p_resolution_code not in (
    'evidence_verified_no_change', 'reservation_released_no_execution',
    'duplicate_execution_no_change', 'false_positive',
    'correction_applied', 'evidence_unavailable'
  ) then raise exception 'invalid_reconciliation_resolution_code'; end if;
  if p_disposition = 'dismissed'
    and p_resolution_code not in ('false_positive', 'evidence_unavailable') then
    raise exception 'invalid_dismissal_resolution_code';
  end if;
  if p_disposition = 'resolved'
    and p_resolution_code in ('false_positive', 'evidence_unavailable') then
    raise exception 'invalid_resolution_code_for_resolved_case';
  end if;

  select * into v_case
  from public.ai_budget_reconciliation_cases review
  where review.reservation_id = p_reservation_id
  for update;
  if not found then raise exception 'reconciliation_case_not_found'; end if;
  if v_case.status <> 'open'
    or v_case.claimed_by <> p_operator_id
    or v_case.claim_expires_at <= now() then
    raise exception 'active_operator_claim_required';
  end if;
  select reservation.status into v_reservation_status
  from public.ai_budget_reservations reservation
  where reservation.id = p_reservation_id;

  if p_resolution_code = 'evidence_verified_no_change'
    and not exists (
      select 1 from public.ai_provider_execution_receipts receipt
      where receipt.reservation_id = p_reservation_id
    ) then raise exception 'provider_receipt_required'; end if;
  if p_resolution_code = 'reservation_released_no_execution'
    and v_reservation_status not in ('released', 'expired') then
    raise exception 'released_or_expired_reservation_required';
  end if;
  if p_resolution_code = 'correction_applied'
    and not exists (
      select 1 from public.ai_budget_correction_requests correction
      where correction.reservation_id = p_reservation_id
        and correction.status = 'applied'
    ) then raise exception 'applied_budget_correction_required'; end if;

  update public.ai_budget_reconciliation_cases
  set status = p_disposition,
      resolution_code = p_resolution_code,
      resolved_by = p_operator_id,
      resolved_at = now(),
      updated_at = now()
  where reservation_id = p_reservation_id;
  insert into public.ai_budget_reconciliation_operator_events (
    reservation_id, operator_id, action, reason_code
  ) values (
    p_reservation_id,
    p_operator_id,
    p_disposition,
    p_resolution_code
  );
  return jsonb_build_object(
    'resolved', p_disposition = 'resolved',
    'dismissed', p_disposition = 'dismissed',
    'resolution_code', p_resolution_code
  );
end;
$$;

create or replace function public.get_ai_budget_reconciliation_queue_metrics(
  p_sla interval default interval '24 hours'
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_sla < interval '15 minutes' or p_sla > interval '30 days' then
    raise exception 'invalid_reconciliation_sla';
  end if;
  return jsonb_build_object(
    'open_count', (
      select count(*) from public.ai_budget_reconciliation_cases review
      where review.status = 'open'
    ),
    'unclaimed_count', (
      select count(*) from public.ai_budget_reconciliation_cases review
      where review.status = 'open'
        and review.claimed_by is null
    ),
    'claimed_count', (
      select count(*) from public.ai_budget_reconciliation_cases review
      where review.status = 'open'
        and review.claimed_by is not null
        and review.claim_expires_at > now()
    ),
    'expired_claim_count', (
      select count(*) from public.ai_budget_reconciliation_cases review
      where review.status = 'open'
        and review.claimed_by is not null
        and review.claim_expires_at <= now()
    ),
    'sla_breached_count', (
      select count(*) from public.ai_budget_reconciliation_cases review
      where review.status = 'open'
        and review.opened_at <= now() - p_sla
    ),
    'oldest_open_age_seconds', coalesce((
      select floor(extract(epoch from now() - min(review.opened_at)))::bigint
      from public.ai_budget_reconciliation_cases review
      where review.status = 'open'
    ), 0),
    'pending_correction_count', (
      select count(*) from public.ai_budget_correction_requests correction
      where correction.status in ('pending_approval', 'approved')
    )
  );
end;
$$;

create or replace function public.purge_expired_ai_budget_operator_evidence(
  p_limit integer default 1000
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_events_deleted integer := 0;
  v_corrections_deleted integer := 0;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_limit not between 1 and 10000 then
    raise exception 'invalid_retention_batch_limit';
  end if;
  with expired as (
    select event.id
    from public.ai_budget_reconciliation_operator_events event
    where event.retention_until <= now()
      and not exists (
        select 1
        from public.ai_budget_reconciliation_cases review
        where review.reservation_id = event.reservation_id
          and review.status = 'open'
      )
    order by event.retention_until
    for update skip locked
    limit p_limit
  )
  delete from public.ai_budget_reconciliation_operator_events event
  using expired
  where event.id = expired.id;
  get diagnostics v_events_deleted = row_count;

  with expired as (
    select correction.id
    from public.ai_budget_correction_requests correction
    where correction.status in ('rejected', 'applied')
      and correction.retention_until <= now()
      and not exists (
        select 1
        from public.ai_budget_reconciliation_cases review
        where review.reservation_id = correction.reservation_id
          and review.status = 'open'
      )
    order by correction.retention_until
    for update skip locked
    limit p_limit
  )
  delete from public.ai_budget_correction_requests correction
  using expired
  where correction.id = expired.id;
  get diagnostics v_corrections_deleted = row_count;
  return jsonb_build_object(
    'operator_events_deleted', v_events_deleted,
    'correction_requests_deleted', v_corrections_deleted
  );
end;
$$;

revoke all on function public.normalize_ai_reconciliation_case() from public;
revoke all on function public.assert_ai_reconciliation_operator(uuid, text)
  from public;
revoke all on function public.claim_ai_budget_reconciliation_cases(
  uuid, integer, interval
) from public;
revoke all on function public.release_ai_budget_reconciliation_claim(uuid, uuid)
  from public;
revoke all on function public.request_ai_budget_correction(
  uuid, uuid, text, integer, integer, text, text
) from public;
revoke all on function public.review_ai_budget_correction(uuid, uuid, text)
  from public;
revoke all on function public.apply_ai_budget_correction(uuid, uuid)
  from public;
revoke all on function public.resolve_ai_budget_reconciliation_case(
  uuid, uuid, text, text
) from public;
revoke all on function public.get_ai_budget_reconciliation_queue_metrics(interval)
  from public;
revoke all on function public.purge_expired_ai_budget_operator_evidence(integer)
  from public;

grant execute on function public.claim_ai_budget_reconciliation_cases(
  uuid, integer, interval
) to service_role;
grant execute on function public.release_ai_budget_reconciliation_claim(uuid, uuid)
  to service_role;
grant execute on function public.request_ai_budget_correction(
  uuid, uuid, text, integer, integer, text, text
) to service_role;
grant execute on function public.review_ai_budget_correction(uuid, uuid, text)
  to service_role;
grant execute on function public.apply_ai_budget_correction(uuid, uuid)
  to service_role;
grant execute on function public.resolve_ai_budget_reconciliation_case(
  uuid, uuid, text, text
) to service_role;
grant execute on function public.get_ai_budget_reconciliation_queue_metrics(interval)
  to service_role;
grant execute on function public.purge_expired_ai_budget_operator_evidence(integer)
  to service_role;

commit;
