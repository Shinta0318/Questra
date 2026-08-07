create table if not exists public.auth_login_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  login_id_norm text not null unique,
  email_norm text not null unique,
  failed_attempts integer not null default 0,
  failure_window_started_at timestamptz,
  last_failed_at timestamptz,
  locked_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint auth_login_accounts_failed_attempts_check
    check (failed_attempts between 0 and 10),
  constraint auth_login_accounts_email_norm_check
    check (email_norm = lower(btrim(email_norm)))
);

alter table public.auth_login_accounts enable row level security;

revoke all on table public.auth_login_accounts from anon, authenticated, public;
grant all on table public.auth_login_accounts to service_role;
grant select, insert, update on table public.auth_login_accounts
  to supabase_auth_admin;

create or replace function public.handle_questra_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  requested_login_id text;
  normalized_login_id text;
  requested_nickname text;
begin
  requested_login_id := nullif(btrim(new.raw_user_meta_data ->> 'login_id'), '');
  requested_nickname := nullif(btrim(new.raw_user_meta_data ->> 'nickname'), '');

  if requested_login_id is not null then
    normalized_login_id := lower(requested_login_id);
    if normalized_login_id !~ '^[a-z0-9][a-z0-9._-]{2,39}$' then
      raise exception using
        errcode = '22023',
        message = 'login_id_invalid';
    end if;
  else
    normalized_login_id := lower(new.email);
  end if;

  insert into public.user_profiles (id, nickname)
  values (new.id, coalesce(requested_nickname, 'キャプテン'))
  on conflict (id) do nothing;

  if new.email is null then
    return new;
  end if;

  insert into public.auth_login_accounts (
    user_id,
    login_id_norm,
    email_norm
  ) values (
    new.id,
    normalized_login_id,
    lower(new.email)
  );

  return new;
end;
$$;

drop trigger if exists on_questra_auth_user_created on auth.users;
create trigger on_questra_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_questra_auth_user();

create or replace function public.sync_questra_auth_email()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if new.email is distinct from old.email then
    update public.auth_login_accounts
    set email_norm = lower(new.email), updated_at = now()
    where user_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_questra_auth_email_changed on auth.users;
create trigger on_questra_auth_email_changed
  after update of email on auth.users
  for each row execute function public.sync_questra_auth_email();

revoke execute on function public.handle_questra_auth_user()
  from anon, authenticated, public;
revoke execute on function public.sync_questra_auth_email()
  from anon, authenticated, public;

insert into public.user_profiles (id, nickname)
select
  users.id,
  coalesce(nullif(btrim(users.raw_user_meta_data ->> 'nickname'), ''), 'キャプテン')
from auth.users as users
on conflict (id) do nothing;

insert into public.auth_login_accounts (user_id, login_id_norm, email_norm)
select users.id, lower(users.email), lower(users.email)
from auth.users as users
where users.email is not null
on conflict (user_id) do nothing;

create or replace function public.record_auth_login_failure(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_count integer;
  window_started timestamptz;
  next_count integer;
begin
  select failed_attempts, failure_window_started_at
  into current_count, window_started
  from public.auth_login_accounts
  where user_id = target_user_id
  for update;

  if not found then
    return;
  end if;

  if window_started is null or window_started < now() - interval '15 minutes' then
    next_count := 1;
    window_started := now();
  else
    next_count := least(current_count + 1, 10);
  end if;

  update public.auth_login_accounts
  set
    failed_attempts = next_count,
    failure_window_started_at = window_started,
    last_failed_at = now(),
    locked_until = case
      when next_count >= 10 then now() + interval '30 minutes'
      else locked_until
    end,
    updated_at = now()
  where user_id = target_user_id;
end;
$$;

create or replace function public.record_auth_login_success(target_user_id uuid)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.auth_login_accounts
  set
    failed_attempts = 0,
    failure_window_started_at = null,
    last_failed_at = null,
    locked_until = null,
    updated_at = now()
  where user_id = target_user_id;
$$;

revoke execute on function public.record_auth_login_failure(uuid)
  from anon, authenticated, public;
revoke execute on function public.record_auth_login_success(uuid)
  from anon, authenticated, public;
grant execute on function public.record_auth_login_failure(uuid) to service_role;
grant execute on function public.record_auth_login_success(uuid) to service_role;

create or replace function public.clear_my_login_lock()
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.auth_login_accounts
  set
    failed_attempts = 0,
    failure_window_started_at = null,
    last_failed_at = null,
    locked_until = null,
    updated_at = now()
  where user_id = auth.uid();
$$;

revoke execute on function public.clear_my_login_lock()
  from anon, public;
grant execute on function public.clear_my_login_lock() to authenticated;

create or replace function public.hook_password_verification_attempt(event jsonb)
returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  account_locked_until timestamptz;
begin
  select locked_until
  into account_locked_until
  from public.auth_login_accounts
  where user_id = (event ->> 'user_id')::uuid;

  if (event ->> 'valid')::boolean is false then
    return jsonb_build_object('decision', 'continue');
  end if;

  if account_locked_until is not null and account_locked_until > now() then
    return jsonb_build_object(
      'decision', 'reject',
      'message', 'Login is temporarily unavailable. Reset your password or try again later.',
      'should_logout_user', false
    );
  end if;

  update public.auth_login_accounts
  set
    failed_attempts = 0,
    failure_window_started_at = null,
    last_failed_at = null,
    locked_until = null,
    updated_at = now()
  where user_id = (event ->> 'user_id')::uuid;

  return jsonb_build_object('decision', 'continue');
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.hook_password_verification_attempt(jsonb)
  to supabase_auth_admin;
revoke execute on function public.hook_password_verification_attempt(jsonb)
  from anon, authenticated, public;
