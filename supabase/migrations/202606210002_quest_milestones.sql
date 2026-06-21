create table if not exists public.quest_milestones (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  title text not null,
  description text not null default '',
  status text not null default 'planned',
  progress numeric(4,3) not null default 0,
  sort_order integer not null default 0,
  guide_type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint quest_milestones_status_check check (
    status in ('planned', 'active', 'completed')
  ),
  constraint quest_milestones_progress_check check (
    progress >= 0 and progress <= 1
  ),
  constraint quest_milestones_guide_type_check check (
    guide_type is null
    or guide_type in ('route', 'knowledge', 'training', 'guild', 'resource', 'opportunity')
  )
);

create index if not exists quest_milestones_owner_quest_idx
  on public.quest_milestones (owner_id, quest_id, sort_order);

create index if not exists quest_milestones_quest_status_idx
  on public.quest_milestones (quest_id, status);

alter table public.quest_milestones enable row level security;

create policy "Quest milestone visibility follows related quest"
  on public.quest_milestones for select
  using (
    exists (
      select 1
      from public.quests q
      where q.id = quest_milestones.quest_id
        and (
          q.owner_id = auth.uid()
          or q.visibility = 'public'
          or (
            q.visibility = 'guild'
            and q.guild_id is not null
            and public.is_guild_member(q.guild_id)
          )
        )
    )
  );

create policy "Quest owners create milestones"
  on public.quest_milestones for insert
  with check (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.quests q
      where q.id = quest_milestones.quest_id
        and q.owner_id = auth.uid()
    )
  );

create policy "Quest owners update milestones"
  on public.quest_milestones for update
  using (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.quests q
      where q.id = quest_milestones.quest_id
        and q.owner_id = auth.uid()
    )
  )
  with check (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.quests q
      where q.id = quest_milestones.quest_id
        and q.owner_id = auth.uid()
    )
  );

create policy "Quest owners delete milestones"
  on public.quest_milestones for delete
  using (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.quests q
      where q.id = quest_milestones.quest_id
        and q.owner_id = auth.uid()
    )
  );
