begin;

create or replace function public.has_current_ai_legal_acceptance(
  p_user_id uuid
) returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.legal_release_policies as policy
    join public.legal_acceptances as acceptance
      on acceptance.region_code = policy.region_code
     and acceptance.eligibility_version = policy.eligibility_version
     and acceptance.terms_version = policy.terms_version
     and acceptance.privacy_version = policy.privacy_version
     and acceptance.ai_disclosure_version = policy.ai_disclosure_version
    where policy.region_code = 'JP'
      and policy.active
      and acceptance.user_id = p_user_id
      and acceptance.minimum_age_confirmed
  );
$$;

revoke all on function public.has_current_ai_legal_acceptance(uuid)
  from public, anon, authenticated;
grant execute on function public.has_current_ai_legal_acceptance(uuid)
  to service_role;

commit;
