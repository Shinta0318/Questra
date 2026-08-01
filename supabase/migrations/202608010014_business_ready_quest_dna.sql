begin;

create table public.quest_dna_versions (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references public.quests(id) on delete cascade,
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  version integer not null check (version > 0),
  attributes jsonb not null check (jsonb_typeof(attributes) = 'object'),
  sensitivity_level text not null default 'normal' check (sensitivity_level in ('normal','restricted','prohibited_for_business')),
  generated_at timestamptz not null default now(),
  unique (quest_id, version)
);

create table public.business_quest_signals (
  signal_id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  anonymous_subject_id uuid not null,
  quest_category text not null,
  quest_stage text not null,
  target_period_band text,
  budget_band text,
  location_scope text,
  experience_level text,
  support_needs text[] not null default '{}',
  commercial_relevance text not null check (commercial_relevance in ('none','possible','active')),
  generated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consent_version integer not null,
  unique (quest_id)
);

alter table public.quest_dna_versions enable row level security;
alter table public.business_quest_signals enable row level security;
create policy "Owners manage Quest DNA versions" on public.quest_dna_versions for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
-- No client policy exists for Business signals. Only vetted server-side aggregation may read them.

comment on table public.business_quest_signals is
  'Private derived signals only. Quest title, description, Mission text, Arc chat, and Arc Memory are forbidden.';

commit;
