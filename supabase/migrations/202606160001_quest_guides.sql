create table if not exists public.quest_guides (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references public.quests(id) on delete cascade,
  guide_type text not null,
  title text not null,
  description text not null default '',
  suggested_actions text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint quest_guides_guide_type_check check (
    guide_type in ('route', 'knowledge', 'training', 'guild', 'resource', 'opportunity')
  )
);

create index if not exists quest_guides_quest_type_idx
  on public.quest_guides (quest_id, guide_type);

alter table public.quest_guides enable row level security;

create policy "Quest guide visibility follows related quest"
  on public.quest_guides for select
  using (
    exists (
      select 1
      from public.quests q
      where q.id = quest_guides.quest_id
        and (
          q.owner_id = auth.uid()
          or q.visibility = 'public'
          or (q.visibility = 'guild' and q.guild_id is not null and public.is_guild_member(q.guild_id))
        )
    )
  );

create policy "Quest owners create guides"
  on public.quest_guides for insert
  with check (
    exists (
      select 1
      from public.quests q
      where q.id = quest_guides.quest_id
        and q.owner_id = auth.uid()
    )
  );

create policy "Quest owners update guides"
  on public.quest_guides for update
  using (
    exists (
      select 1
      from public.quests q
      where q.id = quest_guides.quest_id
        and q.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.quests q
      where q.id = quest_guides.quest_id
        and q.owner_id = auth.uid()
    )
  );

create policy "Quest owners delete guides"
  on public.quest_guides for delete
  using (
    exists (
      select 1
      from public.quests q
      where q.id = quest_guides.quest_id
        and q.owner_id = auth.uid()
    )
  );
