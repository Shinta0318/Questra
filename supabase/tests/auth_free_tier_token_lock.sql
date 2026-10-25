\set ON_ERROR_STOP on

begin;

insert into auth.users (
  id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_user_meta_data
)
select '00000000-0000-4000-8000-000000000569',
       'authenticated', 'authenticated', 'qst569@example.test',
       'test-only', now(), now(), now(),
       jsonb_build_object(
         'region_code', policy.region_code,
         'minimum_age_confirmed', true,
         'eligibility_version', policy.eligibility_version,
         'terms_version', policy.terms_version,
         'privacy_version', policy.privacy_version,
         'ai_disclosure_version', policy.ai_disclosure_version
       )
from public.legal_release_policies as policy
where policy.region_code = 'JP' and policy.active;

update public.auth_login_accounts
set failed_attempts = 10,
    locked_until = now() + interval '30 minutes'
where user_id = '00000000-0000-4000-8000-000000000569';

do $$
begin
  if not exists (
    select 1 from public.auth_login_accounts
    where user_id = '00000000-0000-4000-8000-000000000569'
      and failed_attempts = 10
  ) then
    raise exception 'QST-569: legal fixture or lock state missing';
  end if;
  if has_function_privilege('anon', 'public.hook_questra_access_token(jsonb)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.hook_questra_access_token(jsonb)', 'EXECUTE')
     or not has_function_privilege('supabase_auth_admin', 'public.hook_questra_access_token(jsonb)', 'EXECUTE')
     or has_table_privilege('anon', 'public.auth_login_accounts', 'SELECT')
     or not has_table_privilege('supabase_auth_admin', 'public.auth_login_accounts', 'SELECT')
     or not has_table_privilege('supabase_auth_admin', 'public.auth_login_accounts', 'UPDATE')
     or (select count(*) from pg_policies
         where schemaname = 'public' and tablename = 'auth_login_accounts'
           and policyname in ('auth_login_accounts_auth_admin_read', 'auth_login_accounts_auth_admin_update')
           and 'supabase_auth_admin' = any(roles)) <> 2 then
    raise exception 'QST-569: hook or account table permission boundary';
  end if;
end;
$$;

do $$
declare
  event jsonb := jsonb_build_object(
    'user_id', '00000000-0000-4000-8000-000000000569',
    'claims', jsonb_build_object('sub', '00000000-0000-4000-8000-000000000569')
  );
  answer jsonb;
begin
  answer := public.hook_questra_access_token(
    event || '{"authentication_method":"password"}'::jsonb
  );
  if answer #>> '{error,http_code}' is distinct from '401' then
    raise exception 'QST-569: locked password token was not rejected';
  end if;

  answer := public.hook_questra_access_token(
    event || '{"authentication_method":"recovery"}'::jsonb
  );
  if answer -> 'claims' is distinct from event -> 'claims' then
    raise exception 'QST-569: recovery token lost claims';
  end if;

  answer := public.hook_questra_access_token(
    event || '{"authentication_method":"token_refresh"}'::jsonb
  );
  if answer -> 'claims' is distinct from event -> 'claims' then
    raise exception 'QST-569: existing session refresh was blocked';
  end if;

  answer := public.hook_questra_access_token(
    jsonb_build_object(
      'user_id', '00000000-0000-4000-8000-000000000570',
      'authentication_method', 'password',
      'claims', event -> 'claims'
    )
  );
  if answer #>> '{error,http_code}' is distinct from '401' then
    raise exception 'QST-569: missing login account was accepted';
  end if;

  answer := public.hook_questra_access_token(jsonb_build_object(
    'user_id', '00000000-0000-4000-8000-000000000569',
    'authentication_method', 'password'
  ));
  if answer #>> '{error,http_code}' is distinct from '500' then
    raise exception 'QST-569: invalid token claims were accepted';
  end if;
end;
$$;

update public.auth_login_accounts
set locked_until = null, failed_attempts = 0
where user_id = '00000000-0000-4000-8000-000000000569';

do $$
declare
  answer jsonb;
begin
  answer := public.hook_questra_access_token(jsonb_build_object(
    'user_id', '00000000-0000-4000-8000-000000000569',
    'authentication_method', 'password',
    'claims', jsonb_build_object('sub', '00000000-0000-4000-8000-000000000569')
  ));
  if answer -> 'claims' ->> 'sub' is distinct from
     '00000000-0000-4000-8000-000000000569' then
    raise exception 'QST-569: unlocked password token was blocked';
  end if;
end;
$$;

rollback;

\echo 'QST-569 hook logic and Auth-role grant/policy checks passed; Auth-role execution remains unverified'
