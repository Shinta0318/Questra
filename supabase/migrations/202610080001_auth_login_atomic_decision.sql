create function public.record_auth_login_failure_v2(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  account public.auth_login_accounts%rowtype;
  event_at timestamptz;
  next_count integer;
  window_started timestamptz;
  affected integer;
begin
  select * into account
  from public.auth_login_accounts
  where user_id = target_user_id
  for update;

  if not found then
    return jsonb_build_object('status', 'missing');
  end if;

  event_at := clock_timestamp();
  if account.locked_until is not null and account.locked_until > event_at then
    return jsonb_build_object('status', 'locked');
  end if;

  if account.failure_window_started_at is null
     or account.failure_window_started_at < event_at - interval '15 minutes' then
    next_count := 1;
    window_started := event_at;
  else
    next_count := least(account.failed_attempts + 1, 10);
    window_started := account.failure_window_started_at;
  end if;

  update public.auth_login_accounts
  set failed_attempts = next_count,
      failure_window_started_at = window_started,
      last_failed_at = event_at,
      locked_until = case
        when next_count >= 10 then event_at + interval '30 minutes'
        else null
      end,
      updated_at = event_at
  where user_id = target_user_id;
  get diagnostics affected = row_count;

  if affected <> 1 then
    return jsonb_build_object('status', 'missing');
  end if;
  return jsonb_build_object('status', 'recorded');
end;
$$;

create function public.record_auth_login_success_v2(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  account public.auth_login_accounts%rowtype;
  event_at timestamptz;
  affected integer;
begin
  select * into account
  from public.auth_login_accounts
  where user_id = target_user_id
  for update;

  if not found then
    return jsonb_build_object('status', 'missing');
  end if;

  event_at := clock_timestamp();
  if account.locked_until is not null and account.locked_until > event_at then
    return jsonb_build_object('status', 'locked');
  end if;

  update public.auth_login_accounts
  set failed_attempts = 0,
      failure_window_started_at = null,
      last_failed_at = null,
      locked_until = null,
      updated_at = event_at
  where user_id = target_user_id;
  get diagnostics affected = row_count;

  if affected <> 1 then
    return jsonb_build_object('status', 'missing');
  end if;
  return jsonb_build_object('status', 'recorded');
end;
$$;

revoke all on function public.record_auth_login_failure_v2(uuid) from public, anon, authenticated;
revoke all on function public.record_auth_login_success_v2(uuid) from public, anon, authenticated;
grant execute on function public.record_auth_login_failure_v2(uuid) to service_role;
grant execute on function public.record_auth_login_success_v2(uuid) to service_role;

create or replace function public.hook_password_verification_attempt(event jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  account_locked_until timestamptz;
  event_at timestamptz;
begin
  if (event ->> 'valid')::boolean is not true then
    return jsonb_build_object('decision', 'continue');
  end if;

  select locked_until into account_locked_until
  from public.auth_login_accounts
  where user_id = (event ->> 'user_id')::uuid
  for update;

  if not found then
    return jsonb_build_object(
      'decision', 'reject',
      'message', 'Login is temporarily unavailable.',
      'should_logout_user', false
    );
  end if;

  event_at := clock_timestamp();
  if account_locked_until is not null and account_locked_until > event_at then
    return jsonb_build_object(
      'decision', 'reject',
      'message', 'Login is temporarily unavailable. Reset your password or try again later.',
      'should_logout_user', false
    );
  end if;

  update public.auth_login_accounts
  set failed_attempts = 0,
      failure_window_started_at = null,
      last_failed_at = null,
      locked_until = null,
      updated_at = event_at
  where user_id = (event ->> 'user_id')::uuid;

  return jsonb_build_object('decision', 'continue');
end;
$$;

revoke execute on function public.hook_password_verification_attempt(jsonb)
  from public, anon, authenticated;
grant execute on function public.hook_password_verification_attempt(jsonb)
  to supabase_auth_admin;
