begin;

create table public.support_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  support_source_type text not null check (support_source_type in ('arc','public','business')),
  provider_id uuid,
  offer_id uuid,
  interaction_type text not null check (interaction_type in ('viewed','saved','adopted','dismissed','accepted','reported','action_started','action_completed','refunded')),
  occurred_at timestamptz not null default now(),
  consent_version integer,
  idempotency_key text not null,
  unique (user_id, idempotency_key)
);

create table public.contribution_outcomes (
  id uuid primary key default gen_random_uuid(),
  interaction_id uuid not null references public.support_interactions(id) on delete cascade,
  outcome_type text not null check (outcome_type in ('mission_started','mission_completed','stage_advanced','quest_completed')),
  outcome_at timestamptz not null default now(),
  attribution_confidence numeric(4,3) not null check (attribution_confidence between 0 and 1),
  attribution_method text not null,
  unique (interaction_id, outcome_type)
);

alter table public.support_interactions enable row level security;
alter table public.contribution_outcomes enable row level security;
create policy "Users manage own support interactions" on public.support_interactions for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Users read own contribution outcomes" on public.contribution_outcomes for select
  using (exists (select 1 from public.support_interactions i where i.id = interaction_id and i.user_id = auth.uid()));

comment on table public.contribution_outcomes is
  'Association evidence only. It must not be described as causal attribution without a separate validated method.';

commit;
