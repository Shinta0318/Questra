create table if not exists public.data_rights_requests (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  request_type text not null check (request_type in ('correction', 'consent_withdrawal', 'account_deletion')),
  status text not null default 'submitted' check (status in ('submitted', 'identity_pending', 'reviewing', 'scheduled', 'completed', 'cancelled', 'rejected')),
  scope jsonb not null default '{}'::jsonb,
  submitted_at timestamptz not null default now(),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.data_rights_requests enable row level security;
create policy data_rights_requests_owner_select on public.data_rights_requests
  for select using (owner_id = auth.uid());
create policy data_rights_requests_owner_insert on public.data_rights_requests
  for insert with check (owner_id = auth.uid());

create or replace function public.submit_data_rights_request(
  p_request_type text,
  p_scope jsonb default '{}'::jsonb
) returns public.data_rights_requests
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_result public.data_rights_requests;
begin
  if v_owner is null then raise exception 'Authentication required.'; end if;
  if p_request_type not in ('correction', 'consent_withdrawal', 'account_deletion') then
    raise exception 'Unsupported data rights request.';
  end if;
  insert into public.data_rights_requests(owner_id, request_type, status, scope)
  values (v_owner, p_request_type, 'submitted', coalesce(p_scope, '{}'::jsonb))
  returning * into v_result;
  insert into public.data_rights_audit_events(owner_id, operation, scope_type, target_id)
  values (v_owner, 'rights_request_submitted', p_request_type, v_result.id);
  return v_result;
end;
$$;

revoke all on function public.submit_data_rights_request(text, jsonb) from public;
grant execute on function public.submit_data_rights_request(text, jsonb) to authenticated;
