begin;

create table if not exists public.mission_research_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists mission_research_requests_rate_idx
  on public.mission_research_requests (user_id, created_at desc);

alter table public.mission_research_requests enable row level security;

comment on table public.mission_research_requests is
  'Rate-limit metadata only. Mission text, Quest text, search queries, and fetched content are not retained.';

create table if not exists public.mission_research_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  result_data jsonb not null,
  retrieved_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique (user_id, mission_id)
);

create index if not exists mission_research_results_expiry_idx
  on public.mission_research_results (user_id, expires_at desc);

alter table public.mission_research_results enable row level security;

drop policy if exists "Users view their Mission research" on public.mission_research_results;
create policy "Users view their Mission research"
  on public.mission_research_results for select
  using (user_id = auth.uid());

comment on table public.mission_research_results is
  'Owner-scoped grounded summaries and source metadata with a short cache TTL.';

create table if not exists public.enterprise_support_proposals (
  id uuid primary key default gen_random_uuid(),
  enterprise_name text not null,
  support_role text not null check (support_role in ('sponsor', 'coach', 'partner', 'official_event_host')),
  title text not null,
  description text not null,
  benefit text not null,
  user_cost text not null,
  eligibility text not null,
  region text,
  minimum_age integer check (minimum_age is null or minimum_age >= 0),
  valid_from timestamptz not null,
  valid_until timestamptz not null,
  application_url text not null check (application_url ~ '^https://'),
  sponsorship_disclosure text not null,
  quest_dna_tags text[] not null default '{}',
  review_status text not null default 'draft' check (review_status in ('draft', 'reviewed', 'rejected', 'expired')),
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint enterprise_support_review_check check (
    review_status <> 'reviewed' or (reviewed_by is not null and reviewed_at is not null)
  ),
  constraint enterprise_support_validity_check check (valid_until > valid_from)
);

alter table public.enterprise_support_proposals enable row level security;

comment on table public.enterprise_support_proposals is
  'Reviewed support catalog. Enterprises cannot directly target or read an individual user Quest.';

commit;
