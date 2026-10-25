\set ON_ERROR_STOP on

begin;

create function pg_temp.qst_legal_assert(condition boolean, label text)
returns void
language plpgsql
as $$
begin
  if condition is distinct from true then
    raise exception 'QST-577: %', label;
  end if;
end;
$$;

create function pg_temp.qst_legal_assert_raises(statement text, label text)
returns void
language plpgsql
as $$
declare
  did_raise boolean := false;
begin
  begin
    execute statement;
  exception when others then
    did_raise := true;
  end;
  if not did_raise then
    raise exception 'QST-577: % did not fail', label;
  end if;
end;
$$;

select pg_temp.qst_legal_assert(
  (select count(*) = 1 from public.legal_release_policies
   where region_code = 'JP' and active),
  'one active JP policy exists'
);

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
         'ai_disclosure_version', policy.ai_disclosure_version,
         'legal_accepted_at', now()::text
       )
from (values
  ('00000000-0000-4000-8000-000000005771', 'qst577-first@example.test'),
  ('00000000-0000-4000-8000-000000005772', 'qst577-second@example.test'),
  ('00000000-0000-4000-8000-000000005773', 'qst577-legacy@example.test')
) as fixture(id, email)
cross join public.legal_release_policies as policy
where policy.region_code = 'JP' and policy.active;

select pg_temp.qst_legal_assert(
  (select count(*) = 3 from public.legal_acceptances
   where user_id in (
     '00000000-0000-4000-8000-000000005771',
     '00000000-0000-4000-8000-000000005772',
     '00000000-0000-4000-8000-000000005773'
   ) and source = 'signup'),
  'signup trigger writes one immutable acceptance per account'
);

-- Recreate the state of a pre-migration account in this rolled-back fixture.
delete from public.legal_acceptances
where user_id = '00000000-0000-4000-8000-000000005773';

select pg_temp.qst_legal_assert(
  not has_table_privilege('authenticated', 'public.legal_acceptances', 'INSERT')
  and not has_table_privilege('authenticated', 'public.legal_acceptances', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.legal_acceptances', 'DELETE')
  and has_function_privilege(
    'authenticated',
    'public.accept_current_legal_policy(text,text,text,text,text,boolean,timestamptz)',
    'EXECUTE'
  ),
  'client cannot forge or rewrite an acceptance row'
);

select pg_temp.qst_legal_assert(
  not has_function_privilege(
    'authenticated', 'public.has_current_ai_legal_acceptance(uuid)', 'EXECUTE'
  )
  and not has_function_privilege(
    'anon', 'public.has_current_ai_legal_acceptance(uuid)', 'EXECUTE'
  )
  and has_function_privilege(
    'service_role', 'public.has_current_ai_legal_acceptance(uuid)', 'EXECUTE'
  ),
  'AI legal gate is callable only by the service role'
);

select pg_temp.qst_legal_assert(
  public.has_current_ai_legal_acceptance(
    '00000000-0000-4000-8000-000000005771'
  )
  and public.has_current_ai_legal_acceptance(
    '00000000-0000-4000-8000-000000005772'
  )
  and not public.has_current_ai_legal_acceptance(
    '00000000-0000-4000-8000-000000005773'
  ),
  'only recorded signup acceptances pass the AI gate'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000005771', true);

select pg_temp.qst_legal_assert(
  (select count(*) = 1 from public.legal_acceptances
   where user_id = '00000000-0000-4000-8000-000000005771')
  and (select count(*) = 0 from public.legal_acceptances
       where user_id = '00000000-0000-4000-8000-000000005772'),
  'first user sees only their own acceptance'
);

do $$
declare
  policy public.legal_release_policies;
  first_id uuid;
  repeated_id uuid;
begin
  select * into policy from public.legal_release_policies
  where region_code = 'JP' and active;
  select id into first_id from public.legal_acceptances
  where user_id = auth.uid();
  select (public.accept_current_legal_policy(
    policy.eligibility_version, policy.terms_version, policy.privacy_version,
    policy.ai_disclosure_version, policy.region_code, true, now()
  )).id into repeated_id;
  perform pg_temp.qst_legal_assert(
    first_id = repeated_id
    and (select count(*) = 1 from public.legal_acceptances
         where user_id = auth.uid()),
    'repeat confirmation returns the original record without a duplicate'
  );
  perform pg_temp.qst_legal_assert_raises(
    format('select public.accept_current_legal_policy(%L,%L,%L,%L,%L,true,now())',
      'outdated', policy.terms_version, policy.privacy_version,
      policy.ai_disclosure_version, policy.region_code),
    'outdated policy cannot be accepted'
  );
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000005772', true);
select pg_temp.qst_legal_assert(
  (select count(*) = 1 from public.legal_acceptances
   where user_id = auth.uid())
  and (select count(*) = 0 from public.legal_acceptances
       where user_id = '00000000-0000-4000-8000-000000005771'),
  'second user cannot read the first user acceptance'
);

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000005773', true);
do $$
declare
  policy public.legal_release_policies;
  accepted public.legal_acceptances;
begin
  select * into policy from public.legal_release_policies
  where region_code = 'JP' and active;
  select * into accepted from public.accept_current_legal_policy(
    policy.eligibility_version, policy.terms_version, policy.privacy_version,
    policy.ai_disclosure_version, policy.region_code, true, now()
  );
  perform pg_temp.qst_legal_assert(
    accepted.user_id = auth.uid() and accepted.source = 'account_gate'
    and (select count(*) = 1 from public.legal_acceptances
         where user_id = auth.uid()),
    'legacy account records one explicit confirmation'
  );
end;
$$;

reset role;

select pg_temp.qst_legal_assert(
  public.has_current_ai_legal_acceptance(
    '00000000-0000-4000-8000-000000005773'
  ),
  'explicit legacy acceptance passes the AI gate'
);

update public.legal_release_policies
set terms_version = 'test-next-version'
where region_code = 'JP';

select pg_temp.qst_legal_assert(
  not public.has_current_ai_legal_acceptance(
    '00000000-0000-4000-8000-000000005771'
  ),
  'a changed policy invalidates an old AI acceptance'
);

rollback;

\echo 'QST-577 legal consent once and RLS tests passed'
