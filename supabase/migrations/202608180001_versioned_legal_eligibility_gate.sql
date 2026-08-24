begin;

create table if not exists public.legal_release_policies (
  region_code text primary key,
  minimum_age integer not null check (minimum_age between 18 and 120),
  eligibility_version text not null,
  terms_version text not null,
  privacy_version text not null,
  ai_disclosure_version text not null,
  active boolean not null default false,
  effective_from timestamptz not null default now(),
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  constraint legal_release_policy_region_check check (region_code ~ '^[A-Z]{2}$')
);

insert into public.legal_release_policies (
  region_code,
  minimum_age,
  eligibility_version,
  terms_version,
  privacy_version,
  ai_disclosure_version,
  active
) values (
  'JP',
  18,
  '2026-08-18-beta.1',
  '2026-08-18-beta.1',
  '2026-08-18-beta.1',
  '2026-08-18-beta.1',
  true
)
on conflict (region_code) do update set
  minimum_age = excluded.minimum_age,
  eligibility_version = excluded.eligibility_version,
  terms_version = excluded.terms_version,
  privacy_version = excluded.privacy_version,
  ai_disclosure_version = excluded.ai_disclosure_version,
  active = excluded.active,
  effective_from = now(),
  retired_at = null;

create table if not exists public.legal_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  eligibility_version text not null,
  terms_version text not null,
  privacy_version text not null,
  ai_disclosure_version text not null,
  region_code text not null references public.legal_release_policies(region_code),
  minimum_age_confirmed boolean not null,
  source text not null check (source in ('signup', 'account_gate')),
  accepted_at_client timestamptz,
  accepted_at_server timestamptz not null default now(),
  evidence jsonb not null default '{}'::jsonb,
  unique (
    user_id,
    eligibility_version,
    terms_version,
    privacy_version,
    ai_disclosure_version,
    region_code
  )
);

alter table public.legal_release_policies enable row level security;
alter table public.legal_acceptances enable row level security;

drop policy if exists "Anyone reads active legal policies"
  on public.legal_release_policies;
create policy "Anyone reads active legal policies"
  on public.legal_release_policies for select
  using (active);

drop policy if exists "Users read own legal acceptances"
  on public.legal_acceptances;
create policy "Users read own legal acceptances"
  on public.legal_acceptances for select
  using (user_id = auth.uid());

grant select on public.legal_release_policies to anon, authenticated;
grant select on public.legal_acceptances to authenticated;
revoke insert, update, delete on public.legal_release_policies
  from anon, authenticated;
revoke insert, update, delete on public.legal_acceptances
  from anon, authenticated;

create or replace function public.accept_current_legal_policy(
  p_eligibility_version text,
  p_terms_version text,
  p_privacy_version text,
  p_ai_disclosure_version text,
  p_region_code text,
  p_minimum_age_confirmed boolean,
  p_accepted_at_client timestamptz default null
) returns public.legal_acceptances
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor_id uuid := auth.uid();
  policy public.legal_release_policies;
  result public.legal_acceptances;
begin
  if actor_id is null then
    raise exception 'authentication required';
  end if;

  select * into policy
  from public.legal_release_policies
  where region_code = upper(btrim(p_region_code)) and active
  for share;

  if not found
     or not p_minimum_age_confirmed
     or p_eligibility_version <> policy.eligibility_version
     or p_terms_version <> policy.terms_version
     or p_privacy_version <> policy.privacy_version
     or p_ai_disclosure_version <> policy.ai_disclosure_version then
    raise exception 'legal_acceptance_required';
  end if;

  insert into public.legal_acceptances (
    user_id,
    eligibility_version,
    terms_version,
    privacy_version,
    ai_disclosure_version,
    region_code,
    minimum_age_confirmed,
    source,
    accepted_at_client,
    evidence
  ) values (
    actor_id,
    policy.eligibility_version,
    policy.terms_version,
    policy.privacy_version,
    policy.ai_disclosure_version,
    policy.region_code,
    true,
    'account_gate',
    p_accepted_at_client,
    jsonb_build_object('explicit_action', true, 'server_policy_match', true)
  )
  on conflict (
    user_id,
    eligibility_version,
    terms_version,
    privacy_version,
    ai_disclosure_version,
    region_code
  ) do nothing
  returning * into result;

  if result.id is null then
    select * into result
    from public.legal_acceptances
    where user_id = actor_id
      and eligibility_version = policy.eligibility_version
      and terms_version = policy.terms_version
      and privacy_version = policy.privacy_version
      and ai_disclosure_version = policy.ai_disclosure_version
      and region_code = policy.region_code;
  end if;
  return result;
end;
$$;

grant execute on function public.accept_current_legal_policy(
  text, text, text, text, text, boolean, timestamptz
) to authenticated;

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
  requested_region text;
  policy public.legal_release_policies;
  accepted_at_client timestamptz;
begin
  requested_login_id := nullif(btrim(new.raw_user_meta_data ->> 'login_id'), '');
  requested_nickname := nullif(btrim(new.raw_user_meta_data ->> 'nickname'), '');
  requested_region := upper(nullif(btrim(new.raw_user_meta_data ->> 'region_code'), ''));

  select * into policy
  from public.legal_release_policies
  where region_code = requested_region and active;

  if not found
     or coalesce((new.raw_user_meta_data ->> 'minimum_age_confirmed')::boolean, false) is not true
     or new.raw_user_meta_data ->> 'eligibility_version' <> policy.eligibility_version
     or new.raw_user_meta_data ->> 'terms_version' <> policy.terms_version
     or new.raw_user_meta_data ->> 'privacy_version' <> policy.privacy_version
     or new.raw_user_meta_data ->> 'ai_disclosure_version' <> policy.ai_disclosure_version then
    raise exception using errcode = '22023', message = 'legal_acceptance_required';
  end if;

  begin
    accepted_at_client := (new.raw_user_meta_data ->> 'legal_accepted_at')::timestamptz;
  exception when others then
    accepted_at_client := null;
  end;

  if requested_login_id is not null then
    normalized_login_id := lower(requested_login_id);
    if normalized_login_id !~ '^[a-z0-9][a-z0-9._-]{2,39}$' then
      raise exception using errcode = '22023', message = 'login_id_invalid';
    end if;
  else
    normalized_login_id := lower(new.email);
  end if;

  insert into public.user_profiles (id, nickname)
  values (new.id, coalesce(requested_nickname, 'キャプテン'))
  on conflict (id) do nothing;

  insert into public.legal_acceptances (
    user_id,
    eligibility_version,
    terms_version,
    privacy_version,
    ai_disclosure_version,
    region_code,
    minimum_age_confirmed,
    source,
    accepted_at_client,
    evidence
  ) values (
    new.id,
    policy.eligibility_version,
    policy.terms_version,
    policy.privacy_version,
    policy.ai_disclosure_version,
    policy.region_code,
    true,
    'signup',
    accepted_at_client,
    jsonb_build_object('explicit_action', true, 'server_policy_match', true)
  );

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

revoke execute on function public.handle_questra_auth_user()
  from anon, authenticated, public;

commit;
