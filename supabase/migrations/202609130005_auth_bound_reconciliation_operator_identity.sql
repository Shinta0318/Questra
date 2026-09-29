begin;

alter table public.ai_budget_reconciliation_operators
  add column if not exists auth_user_id uuid references auth.users(id)
    on delete set null,
  add column if not exists actor_kind text not null default 'human',
  add column if not exists identity_bound_at timestamptz;

-- Existing unbound rows cannot safely represent a human action after this
-- migration. Keep them as historical identities, but disable future use.
update public.ai_budget_reconciliation_operators
set enabled = false,
    disabled_at = coalesce(disabled_at, now())
where enabled
  and actor_kind = 'human'
  and auth_user_id is null;

update public.ai_budget_reconciliation_operators
set identity_bound_at = coalesce(identity_bound_at, created_at)
where actor_kind = 'human'
  and auth_user_id is not null;

alter table public.ai_budget_reconciliation_operators
  add constraint ai_budget_reconciliation_actor_kind_check check (
    actor_kind in ('human', 'service_worker')
  ),
  add constraint ai_budget_reconciliation_identity_binding_check check (
    (
      actor_kind = 'human'
      and (
        not enabled
        or (auth_user_id is not null and identity_bound_at is not null)
      )
    ) or (
      actor_kind = 'service_worker'
      and auth_user_id is null
      and identity_bound_at is null
      and operator_role = 'reviewer'
    )
  );

create unique index if not exists ai_budget_reconciliation_auth_user_idx
  on public.ai_budget_reconciliation_operators (auth_user_id)
  where auth_user_id is not null;

alter table public.ai_budget_reconciliation_operator_events
  add column if not exists actor_kind text;

update public.ai_budget_reconciliation_operator_events event
set actor_kind = coalesce((
  select case
    when operator.auth_user_id is null then 'legacy_unbound'
    else operator.actor_kind
  end
  from public.ai_budget_reconciliation_operators operator
  where operator.id = event.operator_id
), 'legacy_unbound')
where event.actor_kind is null;

alter table public.ai_budget_reconciliation_operator_events
  alter column actor_kind set not null,
  add constraint ai_budget_reconciliation_event_actor_kind_check check (
    actor_kind in ('human', 'service_worker', 'legacy_unbound')
  );

create or replace function public.assert_ai_reconciliation_operator(
  p_operator_id uuid,
  p_required_role text default null
) returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_operator public.ai_budget_reconciliation_operators%rowtype;
  v_request_role text := coalesce(auth.role(), '');
begin
  if p_required_role is not null
    and p_required_role not in ('reviewer', 'approver') then
    raise exception 'invalid_operator_role_requirement';
  end if;

  select * into v_operator
  from public.ai_budget_reconciliation_operators operator
  where operator.id = p_operator_id
    and operator.enabled;
  if not found then
    raise exception 'reconciliation_operator_required';
  end if;

  if v_request_role = 'service_role' then
    if v_operator.actor_kind <> 'service_worker' then
      raise exception 'service_worker_operator_required';
    end if;
  elsif v_request_role = 'authenticated' then
    if v_operator.actor_kind <> 'human'
      or v_operator.auth_user_id is distinct from auth.uid() then
      raise exception 'operator_identity_mismatch';
    end if;
  else
    raise exception 'reconciliation_operator_authentication_required';
  end if;

  if p_required_role = 'approver'
    and v_operator.operator_role <> 'approver' then
    raise exception 'reconciliation_approver_required';
  end if;
  return v_operator.operator_role;
end;
$$;

create or replace function public.current_ai_reconciliation_operator(
  p_required_role text default null
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_operator_id uuid;
begin
  if auth.role() is distinct from 'authenticated' or auth.uid() is null then
    raise exception 'authenticated_operator_required';
  end if;
  if p_required_role is not null
    and p_required_role not in ('reviewer', 'approver') then
    raise exception 'invalid_operator_role_requirement';
  end if;

  select operator.id into v_operator_id
  from public.ai_budget_reconciliation_operators operator
  where operator.auth_user_id = auth.uid()
    and operator.actor_kind = 'human'
    and operator.enabled
    and (
      p_required_role is null
      or p_required_role = 'reviewer'
      or operator.operator_role = 'approver'
    );
  if not found then
    raise exception 'reconciliation_operator_required';
  end if;
  return v_operator_id;
end;
$$;

create or replace function public.set_ai_reconciliation_event_actor_kind()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  select operator.actor_kind into new.actor_kind
  from public.ai_budget_reconciliation_operators operator
  where operator.id = new.operator_id
    and operator.enabled;
  if not found then
    raise exception 'reconciliation_operator_required';
  end if;
  return new;
end;
$$;

drop trigger if exists set_ai_reconciliation_event_actor_kind
  on public.ai_budget_reconciliation_operator_events;
create trigger set_ai_reconciliation_event_actor_kind
before insert on public.ai_budget_reconciliation_operator_events
for each row execute function public.set_ai_reconciliation_event_actor_kind();

create or replace function public.enforce_ai_budget_correction_human_actors()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_requested_auth_user uuid;
  v_approved_auth_user uuid;
  v_applied_auth_user uuid;
begin
  select operator.auth_user_id into v_requested_auth_user
  from public.ai_budget_reconciliation_operators operator
  where operator.id = new.requested_by
    and operator.actor_kind = 'human';
  if not found or v_requested_auth_user is null then
    raise exception 'human_correction_requester_required';
  end if;

  if tg_op = 'INSERT' and not exists (
    select 1
    from public.ai_budget_reconciliation_operators operator
    where operator.id = new.requested_by
      and operator.enabled
  ) then
    raise exception 'enabled_correction_requester_required';
  end if;

  if new.approved_by is not null then
    select operator.auth_user_id into v_approved_auth_user
    from public.ai_budget_reconciliation_operators operator
    where operator.id = new.approved_by
      and operator.actor_kind = 'human'
      and operator.operator_role = 'approver'
      and operator.enabled;
    if not found or v_approved_auth_user is null then
      raise exception 'human_correction_approver_required';
    end if;
    if v_approved_auth_user = v_requested_auth_user then
      raise exception 'budget_correction_same_identity_approval_forbidden';
    end if;
  end if;

  if new.applied_by is not null then
    select operator.auth_user_id into v_applied_auth_user
    from public.ai_budget_reconciliation_operators operator
    where operator.id = new.applied_by
      and operator.actor_kind = 'human'
      and operator.operator_role = 'approver'
      and operator.enabled;
    if not found or v_applied_auth_user is null then
      raise exception 'human_correction_applier_required';
    end if;
    if v_applied_auth_user is distinct from v_approved_auth_user then
      raise exception 'correction_approver_must_apply';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_ai_budget_correction_human_actors
  on public.ai_budget_correction_requests;
create trigger enforce_ai_budget_correction_human_actors
before insert or update on public.ai_budget_correction_requests
for each row execute function public.enforce_ai_budget_correction_human_actors();

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

    if new.resolved_by is not null
      and (
        tg_op = 'INSERT'
        or old.status = 'open'
        or old.resolved_by is distinct from new.resolved_by
      )
      and not exists (
        select 1
        from public.ai_budget_reconciliation_operators operator
        where operator.id = new.resolved_by
          and operator.actor_kind = 'human'
          and operator.auth_user_id is not null
          and operator.enabled
      ) then
      raise exception 'human_case_resolver_required';
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

create or replace function public.claim_my_ai_budget_reconciliation_cases(
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
declare
  v_operator_id uuid;
begin
  v_operator_id := public.current_ai_reconciliation_operator('reviewer');
  return query
  select *
  from public.claim_ai_budget_reconciliation_cases(
    v_operator_id,
    p_limit,
    p_lease
  );
end;
$$;

create or replace function public.release_my_ai_budget_reconciliation_claim(
  p_reservation_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return public.release_ai_budget_reconciliation_claim(
    p_reservation_id,
    public.current_ai_reconciliation_operator('reviewer')
  );
end;
$$;

create or replace function public.request_my_ai_budget_correction(
  p_reservation_id uuid,
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
begin
  return public.request_ai_budget_correction(
    p_reservation_id,
    public.current_ai_reconciliation_operator('reviewer'),
    p_corrected_model_name,
    p_corrected_input_tokens,
    p_corrected_output_tokens,
    p_reason_code,
    p_idempotency_key
  );
end;
$$;

create or replace function public.review_my_ai_budget_correction(
  p_request_id uuid,
  p_decision text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return public.review_ai_budget_correction(
    p_request_id,
    public.current_ai_reconciliation_operator('approver'),
    p_decision
  );
end;
$$;

create or replace function public.apply_my_ai_budget_correction(
  p_request_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return public.apply_ai_budget_correction(
    p_request_id,
    public.current_ai_reconciliation_operator('approver')
  );
end;
$$;

create or replace function public.resolve_my_ai_budget_reconciliation_case(
  p_reservation_id uuid,
  p_disposition text,
  p_resolution_code text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return public.resolve_ai_budget_reconciliation_case(
    p_reservation_id,
    public.current_ai_reconciliation_operator('reviewer'),
    p_disposition,
    p_resolution_code
  );
end;
$$;

create or replace function public.get_my_ai_budget_reconciliation_queue_metrics(
  p_sla interval default interval '24 hours'
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.current_ai_reconciliation_operator('reviewer');
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

revoke all on function public.assert_ai_reconciliation_operator(uuid, text)
  from public, anon, authenticated;
revoke all on function public.current_ai_reconciliation_operator(text)
  from public, anon, authenticated;
revoke all on function public.set_ai_reconciliation_event_actor_kind()
  from public, anon, authenticated;
revoke all on function public.enforce_ai_budget_correction_human_actors()
  from public, anon, authenticated;
revoke all on function public.normalize_ai_reconciliation_case()
  from public, anon, authenticated;

revoke all on function public.claim_ai_budget_reconciliation_cases(
  uuid, integer, interval
) from public, anon, authenticated;
revoke all on function public.release_ai_budget_reconciliation_claim(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.request_ai_budget_correction(
  uuid, uuid, text, integer, integer, text, text
) from public, anon, authenticated, service_role;
revoke all on function public.review_ai_budget_correction(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.apply_ai_budget_correction(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.resolve_ai_budget_reconciliation_case(
  uuid, uuid, text, text
) from public, anon, authenticated, service_role;

revoke all on function public.claim_my_ai_budget_reconciliation_cases(
  integer, interval
) from public, anon;
revoke all on function public.release_my_ai_budget_reconciliation_claim(uuid)
  from public, anon;
revoke all on function public.request_my_ai_budget_correction(
  uuid, text, integer, integer, text, text
) from public, anon;
revoke all on function public.review_my_ai_budget_correction(uuid, text)
  from public, anon;
revoke all on function public.apply_my_ai_budget_correction(uuid)
  from public, anon;
revoke all on function public.resolve_my_ai_budget_reconciliation_case(
  uuid, text, text
) from public, anon;
revoke all on function public.get_my_ai_budget_reconciliation_queue_metrics(
  interval
) from public, anon;

grant execute on function public.claim_my_ai_budget_reconciliation_cases(
  integer, interval
) to authenticated;
grant execute on function public.release_my_ai_budget_reconciliation_claim(uuid)
  to authenticated;
grant execute on function public.request_my_ai_budget_correction(
  uuid, text, integer, integer, text, text
) to authenticated;
grant execute on function public.review_my_ai_budget_correction(uuid, text)
  to authenticated;
grant execute on function public.apply_my_ai_budget_correction(uuid)
  to authenticated;
grant execute on function public.resolve_my_ai_budget_reconciliation_case(
  uuid, text, text
) to authenticated;
grant execute on function public.get_my_ai_budget_reconciliation_queue_metrics(
  interval
) to authenticated;

commit;
