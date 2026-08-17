alter table public.data_rights_requests
  add column if not exists reauthenticated_at timestamptz,
  add column if not exists scheduled_for timestamptz,
  add column if not exists cancellable_until timestamptz,
  add column if not exists processing_started_at timestamptz,
  add column if not exists attempt_count integer not null default 0,
  add column if not exists last_error text,
  add column if not exists idempotency_key text;

alter table public.data_rights_audit_events
  drop constraint if exists data_rights_audit_events_operation_check;
alter table public.data_rights_audit_events
  add constraint data_rights_audit_events_operation_check check (
    operation in (
      'export', 'deletion_preview', 'task_deletion',
      'rights_request_submitted', 'rights_request_cancelled',
      'account_deletion_completed', 'account_deletion_failed'
    )
  );

create unique index if not exists data_rights_requests_owner_idempotency_key
  on public.data_rights_requests(owner_id, idempotency_key)
  where idempotency_key is not null;

drop function if exists public.submit_data_rights_request(text, jsonb);

create or replace function public.submit_data_rights_request(
  p_request_type text,
  p_scope jsonb default '{}'::jsonb,
  p_idempotency_key text default null
) returns public.data_rights_requests
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_issued_at timestamptz;
  v_result public.data_rights_requests;
begin
  if v_owner is null then raise exception 'Authentication required.'; end if;
  if p_request_type not in ('correction', 'consent_withdrawal', 'account_deletion') then
    raise exception 'Unsupported data rights request.';
  end if;
  if p_idempotency_key is null or length(trim(p_idempotency_key)) < 8 then
    raise exception 'Idempotency key is required.';
  end if;

  v_issued_at := to_timestamp(coalesce((auth.jwt() ->> 'iat')::double precision, 0));
  if p_request_type = 'account_deletion' and v_issued_at < now() - interval '10 minutes' then
    raise exception 'Recent authentication required.';
  end if;

  if p_request_type = 'account_deletion' then
    select * into v_result from public.data_rights_requests
      where owner_id = v_owner and request_type = 'account_deletion'
        and status in ('scheduled', 'reviewing')
      order by submitted_at desc limit 1;
    if found then return v_result; end if;
  end if;

  select * into v_result from public.data_rights_requests
    where owner_id = v_owner and idempotency_key = p_idempotency_key;
  if found then return v_result; end if;

  insert into public.data_rights_requests(
    owner_id, request_type, status, scope, reauthenticated_at,
    scheduled_for, cancellable_until, idempotency_key
  ) values (
    v_owner,
    p_request_type,
    case when p_request_type = 'account_deletion' then 'scheduled' else 'submitted' end,
    coalesce(p_scope, '{}'::jsonb),
    case when p_request_type = 'account_deletion' then now() else null end,
    case when p_request_type = 'account_deletion' then now() + interval '72 hours' else null end,
    case when p_request_type = 'account_deletion' then now() + interval '72 hours' else null end,
    trim(p_idempotency_key)
  ) returning * into v_result;

  insert into public.data_rights_audit_events(owner_id, operation, scope_type, target_id)
  values (v_owner, 'rights_request_submitted', p_request_type, v_result.id);
  return v_result;
end;
$$;

create or replace function public.cancel_my_data_rights_request(p_request_id uuid)
returns public.data_rights_requests
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_result public.data_rights_requests;
begin
  if v_owner is null then raise exception 'Authentication required.'; end if;
  update public.data_rights_requests
    set status = 'cancelled', resolved_at = now(), updated_at = now()
    where id = p_request_id and owner_id = v_owner and status = 'scheduled'
      and cancellable_until > now()
    returning * into v_result;
  if not found then raise exception 'Request cannot be cancelled.'; end if;
  insert into public.data_rights_audit_events(owner_id, operation, scope_type, target_id)
  values (v_owner, 'rights_request_cancelled', v_result.request_type, v_result.id);
  return v_result;
end;
$$;

create or replace function public.claim_scheduled_account_deletions(p_limit integer default 20)
returns setof public.data_rights_requests
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.role() <> 'service_role' then raise exception 'Worker authorization required.'; end if;
  return query
  with candidates as (
    select id from public.data_rights_requests
      where request_type = 'account_deletion' and status = 'scheduled'
        and scheduled_for <= now() and attempt_count < 5
      order by scheduled_for
      for update skip locked
      limit least(greatest(p_limit, 1), 100)
  )
  update public.data_rights_requests r
    set status = 'reviewing', processing_started_at = now(),
        attempt_count = attempt_count + 1, updated_at = now()
    from candidates c where r.id = c.id
    returning r.*;
end;
$$;

create or replace function public.resolve_account_deletion_worker(
  p_request_id uuid, p_completed boolean, p_error text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if auth.role() <> 'service_role' then raise exception 'Worker authorization required.'; end if;
  update public.data_rights_requests set
    status = case when p_completed then 'completed' else 'scheduled' end,
    resolved_at = case when p_completed then now() else null end,
    scheduled_for = case when p_completed then scheduled_for else now() + interval '1 hour' end,
    last_error = case when p_completed then null else left(coalesce(p_error, 'worker_failed'), 500) end,
    updated_at = now()
  where id = p_request_id and status = 'reviewing';
end;
$$;

revoke all on function public.submit_data_rights_request(text, jsonb, text) from public;
revoke all on function public.cancel_my_data_rights_request(uuid) from public;
revoke all on function public.claim_scheduled_account_deletions(integer) from public;
revoke all on function public.resolve_account_deletion_worker(uuid, boolean, text) from public;
grant execute on function public.submit_data_rights_request(text, jsonb, text) to authenticated;
grant execute on function public.cancel_my_data_rights_request(uuid) to authenticated;
grant execute on function public.claim_scheduled_account_deletions(integer) to service_role;
grant execute on function public.resolve_account_deletion_worker(uuid, boolean, text) to service_role;
