begin;

alter table public.missions
  add column if not exists route_state text not null default 'active';

alter table public.missions
  add constraint missions_route_state_check
    check (route_state in ('active', 'paused', 'removed')) not valid;
alter table public.missions validate constraint missions_route_state_check;

create table if not exists public.route_versions (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references public.quests(id) on delete cascade,
  version_number integer not null check (version_number > 0),
  status text not null check (status in ('proposed', 'active', 'superseded', 'rolled_back')),
  generated_by text not null check (generated_by in ('arc', 'user', 'system')),
  generation_reason text not null,
  ai_model text,
  prompt_version text,
  route_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid references public.user_profiles(id) on delete set null,
  unique (quest_id, version_number)
);

create table if not exists public.route_change_proposals (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references public.quests(id) on delete cascade,
  route_version_id uuid not null references public.route_versions(id) on delete cascade,
  proposal_type text not null,
  summary text not null,
  reason text not null,
  confidence_score double precision not null check (confidence_score between 0 and 1),
  status text not null default 'pending' check (
    status in ('pending', 'accepted', 'partiallyAccepted', 'rejected', 'expired', 'rolledBack')
  ),
  accepted_item_ids uuid[] not null default '{}'::uuid[],
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.route_change_items (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.route_change_proposals(id) on delete cascade,
  action_type text not null check (
    action_type in ('add', 'remove', 'replace', 'reorder', 'split', 'merge', 'reschedule', 'reestimate', 'pause', 'resume')
  ),
  target_mission_id uuid references public.missions(id) on delete set null,
  title text not null,
  before_data jsonb not null default '{}'::jsonb,
  after_data jsonb not null default '{}'::jsonb,
  reason text not null,
  safety_level integer not null check (safety_level between 1 and 3)
);

create table if not exists public.mission_progress_events (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references public.quests(id) on delete cascade,
  mission_id uuid references public.missions(id) on delete set null,
  event_type text not null check (
    event_type in ('completed', 'postponed', 'skipped', 'started', 'paused', 'deadline_missed', 'user_feedback')
  ),
  event_key text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (quest_id, event_key)
);

create index if not exists route_versions_quest_idx
  on public.route_versions(quest_id, version_number desc);
create index if not exists route_proposals_quest_status_idx
  on public.route_change_proposals(quest_id, status, created_at desc);
create index if not exists mission_progress_events_quest_idx
  on public.mission_progress_events(quest_id, created_at desc);

alter table public.route_versions enable row level security;
alter table public.route_change_proposals enable row level security;
alter table public.route_change_items enable row level security;
alter table public.mission_progress_events enable row level security;

create policy route_versions_owner_all on public.route_versions
  for all using (
    exists (select 1 from public.quests q where q.id = route_versions.quest_id and q.owner_id = auth.uid())
  ) with check (
    exists (select 1 from public.quests q where q.id = route_versions.quest_id and q.owner_id = auth.uid())
  );

create policy route_proposals_owner_all on public.route_change_proposals
  for all using (
    exists (select 1 from public.quests q where q.id = route_change_proposals.quest_id and q.owner_id = auth.uid())
  ) with check (
    exists (select 1 from public.quests q where q.id = route_change_proposals.quest_id and q.owner_id = auth.uid())
  );

create policy route_items_owner_all on public.route_change_items
  for all using (
    exists (
      select 1 from public.route_change_proposals p
      join public.quests q on q.id = p.quest_id
      where p.id = proposal_id and q.owner_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.route_change_proposals p
      join public.quests q on q.id = p.quest_id
      where p.id = proposal_id and q.owner_id = auth.uid()
    )
  );

create policy mission_progress_events_owner_all on public.mission_progress_events
  for all using (
    exists (select 1 from public.quests q where q.id = mission_progress_events.quest_id and q.owner_id = auth.uid())
  ) with check (
    exists (select 1 from public.quests q where q.id = mission_progress_events.quest_id and q.owner_id = auth.uid())
  );

comment on table public.route_change_proposals is
  'Arc route changes remain proposals until the Quest owner explicitly resolves them.';
comment on column public.missions.route_state is
  'Soft route membership preserves Mission and Trail history during replanning.';

grant select, insert, update, delete
  on public.route_versions,
     public.route_change_proposals,
     public.route_change_items,
     public.mission_progress_events
  to authenticated;

commit;
