begin;

alter table public.data_rights_requests
  add column if not exists due_at timestamptz,
  add column if not exists fulfillment_policy_version text not null default '2026-08-25.v1',
  add column if not exists resolution_code text;

revoke insert, update, delete on public.data_rights_requests from anon, authenticated;
grant select on public.data_rights_requests to authenticated;

update public.data_rights_requests
set due_at = submitted_at + case request_type
  when 'consent_withdrawal' then interval '1 day'
  when 'account_deletion' then interval '3 days'
  else interval '30 days'
end
where due_at is null;

create or replace function public.assign_data_rights_request_sla()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.due_at := new.submitted_at + case new.request_type
    when 'consent_withdrawal' then interval '1 day'
    when 'account_deletion' then interval '3 days'
    else interval '30 days'
  end;
  new.fulfillment_policy_version := '2026-08-25.v1';
  return new;
end;
$$;

drop trigger if exists data_rights_request_sla on public.data_rights_requests;
create trigger data_rights_request_sla
before insert on public.data_rights_requests
for each row execute function public.assign_data_rights_request_sla();

alter table public.data_rights_audit_events
  drop constraint if exists data_rights_audit_events_operation_check;
alter table public.data_rights_audit_events
  add constraint data_rights_audit_events_operation_check check (
    operation in (
      'export', 'deletion_preview', 'task_deletion',
      'rights_request_submitted', 'rights_request_cancelled',
      'rights_request_completed', 'rights_request_rejected',
      'account_deletion_completed', 'account_deletion_failed'
    )
  );

create table if not exists public.data_rights_fulfillment_receipts (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  request_type text not null check (
    request_type in ('correction', 'consent_withdrawal', 'account_deletion')
  ),
  outcome text not null check (outcome in ('completed', 'rejected')),
  resolution_code text not null,
  fulfillment_policy_version text not null,
  completed_at timestamptz not null default now()
);

alter table public.data_rights_fulfillment_receipts enable row level security;
revoke all on public.data_rights_fulfillment_receipts from anon, authenticated;

create or replace function public.fulfill_pending_consent_withdrawals(
  p_limit integer default 20
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_request public.data_rights_requests;
  v_purpose_code text;
  v_processed integer := 0;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Worker authorization required.';
  end if;
  for v_request in
    select * from public.data_rights_requests
    where request_type = 'consent_withdrawal' and status = 'submitted'
    order by submitted_at
    for update skip locked
    limit least(greatest(p_limit, 1), 100)
  loop
    v_purpose_code := v_request.scope ->> 'purpose_code';
    update public.user_consents
    set status = 'withdrawn', withdrawn_at = now(), granted_at = null,
        source = 'settings', evidence = jsonb_build_object('explicit_action', true)
    where user_id = v_request.owner_id and purpose_code = v_purpose_code;

    if v_purpose_code in (
      'business_segment_analysis', 'business_recommendations', 'personal_data_sharing'
    ) then
      delete from public.business_quest_signals where owner_id = v_request.owner_id;
    end if;

    update public.data_rights_requests
    set status = 'completed', resolved_at = now(), updated_at = now(),
        resolution_code = 'consent_withdrawn'
    where id = v_request.id;
    insert into public.data_rights_audit_events(
      owner_id, operation, scope_type, target_id
    ) values (
      v_request.owner_id, 'rights_request_completed',
      'consent_withdrawal', v_request.id
    );
    insert into public.data_rights_fulfillment_receipts(
      request_id, request_type, outcome, resolution_code,
      fulfillment_policy_version
    ) values (
      v_request.id, 'consent_withdrawal', 'completed',
      'consent_withdrawn', v_request.fulfillment_policy_version
    ) on conflict (request_id) do nothing;
    v_processed := v_processed + 1;
  end loop;
  return jsonb_build_object('processed_count', v_processed);
end;
$$;

create or replace function public.claim_pending_correction_requests(
  p_limit integer default 20
) returns table(request_id uuid, due_at timestamptz, target_type text)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Operator authorization required.';
  end if;
  return query
  with candidates as (
    select id from public.data_rights_requests
    where request_type = 'correction' and status = 'submitted'
    order by due_at, submitted_at
    for update skip locked
    limit least(greatest(p_limit, 1), 100)
  ), updated as (
    update public.data_rights_requests request
    set status = 'reviewing', processing_started_at = now(), updated_at = now()
    from candidates where request.id = candidates.id
    returning request.id, request.due_at, request.scope ->> 'target_type' as target_type
  )
  select updated.id, updated.due_at, updated.target_type from updated;
end;
$$;

create or replace function public.claim_data_correction_request(
  p_request_id uuid
) returns table(request_id uuid, due_at timestamptz, target_type text)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Operator authorization required.';
  end if;
  return query
  update public.data_rights_requests request
  set status = 'reviewing', processing_started_at = now(), updated_at = now()
  where request.id = p_request_id and request.request_type = 'correction'
    and request.status = 'submitted'
  returning request.id, request.due_at, request.scope ->> 'target_type';
end;
$$;

create or replace function public.fulfill_consent_withdrawal_request(
  p_request_id uuid
) returns boolean
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_request public.data_rights_requests;
  v_purpose_code text;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Worker authorization required.';
  end if;
  select * into v_request from public.data_rights_requests
  where id = p_request_id and request_type = 'consent_withdrawal'
    and status = 'submitted' for update;
  if not found then return false; end if;
  v_purpose_code := v_request.scope ->> 'purpose_code';
  update public.user_consents
  set status = 'withdrawn', withdrawn_at = now(), granted_at = null,
      source = 'settings', evidence = jsonb_build_object('explicit_action', true)
  where user_id = v_request.owner_id and purpose_code = v_purpose_code;
  if v_purpose_code in (
    'business_segment_analysis', 'business_recommendations', 'personal_data_sharing'
  ) then
    delete from public.business_quest_signals where owner_id = v_request.owner_id;
  end if;
  update public.data_rights_requests
  set status = 'completed', resolved_at = now(), updated_at = now(),
      resolution_code = 'consent_withdrawn'
  where id = v_request.id;
  insert into public.data_rights_audit_events(
    owner_id, operation, scope_type, target_id
  ) values (
    v_request.owner_id, 'rights_request_completed',
    'consent_withdrawal', v_request.id
  );
  insert into public.data_rights_fulfillment_receipts(
    request_id, request_type, outcome, resolution_code,
    fulfillment_policy_version
  ) values (
    v_request.id, 'consent_withdrawal', 'completed',
    'consent_withdrawn', v_request.fulfillment_policy_version
  ) on conflict (request_id) do nothing;
  return true;
end;
$$;

create or replace function public.claim_account_deletion_request(
  p_request_id uuid
) returns public.data_rights_requests
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_result public.data_rights_requests;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Worker authorization required.';
  end if;
  update public.data_rights_requests
  set status = 'reviewing', processing_started_at = now(),
      attempt_count = attempt_count + 1, updated_at = now()
  where id = p_request_id and request_type = 'account_deletion'
    and status = 'scheduled' and scheduled_for <= now() and attempt_count < 5
  returning * into v_result;
  if not found then raise exception 'Deletion request is not due.'; end if;
  return v_result;
end;
$$;

create or replace function public.resolve_data_correction_request(
  p_request_id uuid,
  p_resolution_code text
) returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_request public.data_rights_requests;
  v_outcome text;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Operator authorization required.';
  end if;
  if p_resolution_code not in (
    'applied', 'no_change_required', 'identity_unverified', 'unsupported'
  ) then
    raise exception 'Unsupported resolution code.';
  end if;
  select * into v_request from public.data_rights_requests
  where id = p_request_id and request_type = 'correction'
    and status in ('submitted', 'reviewing')
  for update;
  if not found then raise exception 'Correction request is not pending.'; end if;

  v_outcome := case when p_resolution_code in ('applied', 'no_change_required')
    then 'completed' else 'rejected' end;
  update public.data_rights_requests
  set status = v_outcome, resolved_at = now(), updated_at = now(),
      resolution_code = p_resolution_code
  where id = p_request_id;
  insert into public.data_rights_audit_events(
    owner_id, operation, scope_type, target_id
  ) values (
    v_request.owner_id,
    case when v_outcome = 'completed' then 'rights_request_completed'
      else 'rights_request_rejected' end,
    'correction', v_request.id
  );
  insert into public.data_rights_fulfillment_receipts(
    request_id, request_type, outcome, resolution_code,
    fulfillment_policy_version
  ) values (
    v_request.id, 'correction', v_outcome, p_resolution_code,
    v_request.fulfillment_policy_version
  ) on conflict (request_id) do nothing;
end;
$$;

create or replace function public.resolve_account_deletion_worker(
  p_request_id uuid, p_completed boolean, p_error text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_request public.data_rights_requests;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Worker authorization required.';
  end if;
  select * into v_request from public.data_rights_requests
  where id = p_request_id and request_type = 'account_deletion'
    and status = 'reviewing' for update;
  if not found then return; end if;

  update public.data_rights_requests set
    status = case when p_completed then 'completed' else 'scheduled' end,
    resolved_at = case when p_completed then now() else null end,
    scheduled_for = case when p_completed then scheduled_for else now() + interval '1 hour' end,
    last_error = case when p_completed then null else left(coalesce(p_error, 'worker_failed'), 100) end,
    resolution_code = case when p_completed then 'account_soft_deleted' else null end,
    updated_at = now()
  where id = p_request_id;

  insert into public.data_rights_audit_events(
    owner_id, operation, scope_type, target_id
  ) values (
    v_request.owner_id,
    case when p_completed then 'account_deletion_completed'
      else 'account_deletion_failed' end,
    'account_deletion', v_request.id
  );
  if p_completed then
    insert into public.data_rights_fulfillment_receipts(
      request_id, request_type, outcome, resolution_code,
      fulfillment_policy_version
    ) values (
      v_request.id, 'account_deletion', 'completed',
      'account_soft_deleted', v_request.fulfillment_policy_version
    ) on conflict (request_id) do nothing;
  end if;
end;
$$;

create or replace function public.get_data_rights_fulfillment_metrics()
returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Operator authorization required.';
  end if;
  return (
    select jsonb_build_object(
      'pending', count(*) filter (where status in ('submitted', 'reviewing', 'scheduled')),
      'overdue', count(*) filter (
        where status in ('submitted', 'reviewing', 'scheduled') and due_at < now()
      ),
      'completed', count(*) filter (where status = 'completed'),
      'rejected', count(*) filter (where status = 'rejected')
    ) from public.data_rights_requests
  );
end;
$$;

revoke all on function public.fulfill_pending_consent_withdrawals(integer) from public;
revoke all on function public.claim_pending_correction_requests(integer) from public;
revoke all on function public.claim_data_correction_request(uuid) from public;
revoke all on function public.fulfill_consent_withdrawal_request(uuid) from public;
revoke all on function public.claim_account_deletion_request(uuid) from public;
revoke all on function public.resolve_data_correction_request(uuid, text) from public;
revoke all on function public.resolve_account_deletion_worker(uuid, boolean, text) from public;
revoke all on function public.get_data_rights_fulfillment_metrics() from public;
grant execute on function public.fulfill_pending_consent_withdrawals(integer) to service_role;
grant execute on function public.claim_pending_correction_requests(integer) to service_role;
grant execute on function public.claim_data_correction_request(uuid) to service_role;
grant execute on function public.fulfill_consent_withdrawal_request(uuid) to service_role;
grant execute on function public.claim_account_deletion_request(uuid) to service_role;
grant execute on function public.resolve_data_correction_request(uuid, text) to service_role;
grant execute on function public.resolve_account_deletion_worker(uuid, boolean, text) to service_role;
grant execute on function public.get_data_rights_fulfillment_metrics() to service_role;

commit;
