-- The Free plan cannot run the password verification hook. Guard password
-- token issuance with the Free-plan custom access token hook instead.
grant usage on schema public to supabase_auth_admin;
grant select, update on public.auth_login_accounts to supabase_auth_admin;

create policy auth_login_accounts_auth_admin_read
on public.auth_login_accounts
for select to supabase_auth_admin
using (true);

-- Kept for the legacy password hook on supported plans. It is disabled in
-- the Free-plan config but must not silently fail RLS if enabled later.
create policy auth_login_accounts_auth_admin_update
on public.auth_login_accounts
for update to supabase_auth_admin
using (true)
with check (true);

create function public.hook_questra_access_token(event jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  account_locked_until timestamptz;
  account_id uuid;
begin
  if jsonb_typeof(event -> 'claims') is distinct from 'object' then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 500, 'message', 'Invalid token claims.'
    ));
  end if;

  -- Recovery and refresh tokens must remain available so a locked user can
  -- reset a password or continue an already authenticated session.
  if event ->> 'authentication_method' = 'password' then
    account_id := nullif(event ->> 'user_id', '')::uuid;
    select locked_until into account_locked_until
    from public.auth_login_accounts
    where user_id = account_id;

    if not found then
      return jsonb_build_object('error', jsonb_build_object(
        'http_code', 401, 'message', 'Login is temporarily unavailable.'
      ));
    end if;

    if account_locked_until is not null
       and account_locked_until > clock_timestamp() then
      return jsonb_build_object('error', jsonb_build_object(
        'http_code', 401,
        'message', 'Login is temporarily unavailable. Reset your password or try again later.'
      ));
    end if;
  end if;

  return jsonb_build_object('claims', event -> 'claims');
end;
$$;

revoke execute on function public.hook_questra_access_token(jsonb)
  from public, anon, authenticated;
grant execute on function public.hook_questra_access_token(jsonb)
  to supabase_auth_admin;
