create table if not exists public.arc_emotion_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  emotion text not null,
  source_type text not null,
  reason text not null default '',
  source_id uuid,
  quest_id uuid references public.quests(id) on delete set null,
  mission_id uuid references public.missions(id) on delete set null,
  trail_id uuid references public.trails(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists arc_emotion_events_owner_created_idx
  on public.arc_emotion_events(owner_id, created_at desc);

alter table public.arc_emotion_events enable row level security;

create policy "Users read their own Arc emotion events"
  on public.arc_emotion_events
  for select
  using (owner_id = auth.uid());

create policy "Users create their own Arc emotion events"
  on public.arc_emotion_events
  for insert
  with check (owner_id = auth.uid());

create policy "Users delete their own Arc emotion events"
  on public.arc_emotion_events
  for delete
  using (owner_id = auth.uid());
