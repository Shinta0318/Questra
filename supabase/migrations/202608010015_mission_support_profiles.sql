begin;

create table public.mission_support_profiles (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.missions(id) on delete cascade,
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  version integer not null default 1,
  support_types text[] not null default '{}',
  external_service_needed boolean not null default false,
  provider_categories text[] not null default '{}',
  commercial_intent text not null default 'none' check (commercial_intent in ('none','awareness','consideration','preparation','ready_for_action')),
  estimated_action_window text not null default 'unknown' check (estimated_action_window in ('now','within_7_days','within_30_days','within_90_days','later','unknown')),
  sponsorable boolean not null default false,
  sensitivity_level text not null default 'normal' check (sensitivity_level in ('normal','restricted','prohibited')),
  user_consent_required boolean not null default true,
  business_recommendations_enabled boolean not null default false,
  confidence numeric(4,3) not null default 0 check (confidence between 0 and 1),
  source text not null check (source in ('arc','system','user')),
  updated_at timestamptz not null default now(),
  unique (mission_id, version)
);

alter table public.mission_support_profiles enable row level security;
create policy "Owners manage Mission support profiles" on public.mission_support_profiles for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

comment on table public.mission_support_profiles is
  'Support classification is downstream of Mission planning and must never alter Mission content for commercial reasons.';

commit;
