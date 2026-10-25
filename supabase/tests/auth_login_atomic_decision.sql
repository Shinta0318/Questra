\set ON_ERROR_STOP on

begin;

create function pg_temp.qst_auth_assert(condition boolean, label text)
returns void
language plpgsql
as $$
begin
  if condition is distinct from true then
    raise exception 'QST-557: %', label;
  end if;
end;
$$;

insert into auth.users (
  id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_user_meta_data
)
select fixture.id::uuid, 'authenticated', 'authenticated', fixture.email,
       'test-only', now(), now(), now(),
       jsonb_build_object(
         'region_code', policy.region_code,
         'minimum_age_confirmed', true,
         'eligibility_version', policy.eligibility_version,
         'terms_version', policy.terms_version,
         'privacy_version', policy.privacy_version,
         'ai_disclosure_version', policy.ai_disclosure_version
       )
from (values
  ('00000000-0000-4000-8000-000000000557', 'qst557-first@example.test'),
  ('00000000-0000-4000-8000-000000000558', 'qst557-second@example.test')
) as fixture(id, email)
cross join public.legal_release_policies as policy
where policy.region_code = 'JP' and policy.active;

select pg_temp.qst_auth_assert(
  (select count(*) = 2 from auth.users
   where id in ('00000000-0000-4000-8000-000000000557',
                '00000000-0000-4000-8000-000000000558')),
  'legal-policy-compliant fixture users exist'
);

select pg_temp.qst_auth_assert(
  public.record_auth_login_success_v2('00000000-0000-4000-8000-000000000559') ->> 'status' = 'missing',
  'missing account cannot claim a successful login'
);

select pg_temp.qst_auth_assert(
  not has_function_privilege('anon', 'public.record_auth_login_success_v2(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.record_auth_login_failure_v2(uuid)', 'EXECUTE')
  and has_function_privilege('service_role', 'public.record_auth_login_success_v2(uuid)', 'EXECUTE'),
  'counter RPC permission boundary'
);

select public.record_auth_login_failure_v2('00000000-0000-4000-8000-000000000557')
from generate_series(1, 10);

select pg_temp.qst_auth_assert(
  (select failed_attempts = 10 and locked_until > now()
   from public.auth_login_accounts
   where user_id = '00000000-0000-4000-8000-000000000557'),
  'ten failures lock the first account'
);

select pg_temp.qst_auth_assert(
  public.record_auth_login_success_v2('00000000-0000-4000-8000-000000000557') ->> 'status' = 'locked',
  'correct credentials cannot bypass a current lock'
);

select pg_temp.qst_auth_assert(
  public.record_auth_login_failure_v2('00000000-0000-4000-8000-000000000557') ->> 'status' = 'locked',
  'additional attempts do not change a current lock'
);

select pg_temp.qst_auth_assert(
  public.hook_password_verification_attempt(jsonb_build_object(
    'user_id', '00000000-0000-4000-8000-000000000557', 'valid', true
  )) ->> 'decision' = 'reject',
  'Auth password hook rejects a locked account'
);

select pg_temp.qst_auth_assert(
  (select failed_attempts = 0 and locked_until is null
   from public.auth_login_accounts
   where user_id = '00000000-0000-4000-8000-000000000558'),
  'second account is unaffected'
);

select pg_temp.qst_auth_assert(
  public.hook_password_verification_attempt(jsonb_build_object(
    'user_id', '00000000-0000-4000-8000-000000000557', 'valid', false
  )) ->> 'decision' = 'continue',
  'invalid password hook does not clear an existing lock'
);
select pg_temp.qst_auth_assert(
  (select failed_attempts = 10 and locked_until > now()
   from public.auth_login_accounts
   where user_id = '00000000-0000-4000-8000-000000000557'),
  'invalid password hook preserves lock state'
);

update public.auth_login_accounts
set locked_until = now() - interval '1 second',
    failure_window_started_at = now() - interval '16 minutes'
where user_id = '00000000-0000-4000-8000-000000000557';

select pg_temp.qst_auth_assert(
  public.record_auth_login_failure_v2('00000000-0000-4000-8000-000000000557') ->> 'status' = 'recorded',
  'expired failure window accepts the next attempt'
);
select pg_temp.qst_auth_assert(
  (select failed_attempts = 1 and locked_until is null
   from public.auth_login_accounts
   where user_id = '00000000-0000-4000-8000-000000000557'),
  'expired window starts at one failure'
);
select pg_temp.qst_auth_assert(
  public.record_auth_login_success_v2('00000000-0000-4000-8000-000000000557') ->> 'status' = 'recorded',
  'unlocked success records one updated account'
);
select pg_temp.qst_auth_assert(
  (select failed_attempts = 0 and locked_until is null
   from public.auth_login_accounts
   where user_id = '00000000-0000-4000-8000-000000000557'),
  'successful login clears failure state'
);

rollback;

\echo 'QST-557 auth login atomic decision tests passed'
