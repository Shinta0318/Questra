create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  name text not null,
  normalized_name text not null,
  source_type text not null default 'ai',
  usage_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, normalized_name),
  constraint tags_source_type_check check (source_type in ('ai', 'manual', 'system')),
  constraint tags_usage_count_check check (usage_count >= 0)
);

create table if not exists public.entity_tags (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  tag_id uuid not null references public.tags(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  confidence numeric(3,2) not null default 0.72,
  source_type text not null default 'ai',
  created_at timestamptz not null default now(),
  unique (owner_id, entity_type, entity_id, tag_id),
  constraint entity_tags_entity_type_check check (
    entity_type in ('quest', 'mission', 'trail', 'arc_memory')
  ),
  constraint entity_tags_source_type_check check (source_type in ('ai', 'manual', 'system')),
  constraint entity_tags_confidence_check check (confidence >= 0 and confidence <= 1)
);

create index if not exists tags_owner_normalized_idx
  on public.tags (owner_id, normalized_name);

create index if not exists tags_owner_usage_idx
  on public.tags (owner_id, usage_count desc);

create index if not exists entity_tags_owner_entity_idx
  on public.entity_tags (owner_id, entity_type, entity_id);

create index if not exists entity_tags_owner_tag_idx
  on public.entity_tags (owner_id, tag_id);

alter table public.tags enable row level security;
alter table public.entity_tags enable row level security;

create policy "Users read their own tags"
  on public.tags for select
  using (owner_id = auth.uid());

create policy "Users create their own tags"
  on public.tags for insert
  with check (owner_id = auth.uid());

create policy "Users update their own tags"
  on public.tags for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "Users delete their own tags"
  on public.tags for delete
  using (owner_id = auth.uid());

create policy "Users read their own entity tags"
  on public.entity_tags for select
  using (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.tags t
      where t.id = entity_tags.tag_id
        and t.owner_id = auth.uid()
    )
  );

create policy "Users create their own entity tags"
  on public.entity_tags for insert
  with check (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.tags t
      where t.id = entity_tags.tag_id
        and t.owner_id = auth.uid()
    )
    and (
      (entity_type = 'quest' and exists (
        select 1 from public.quests q
        where q.id = entity_tags.entity_id
          and q.owner_id = auth.uid()
      ))
      or (entity_type = 'mission' and exists (
        select 1
        from public.missions m
        join public.quests q on q.id = m.quest_id
        where m.id = entity_tags.entity_id
          and q.owner_id = auth.uid()
      ))
      or (entity_type = 'trail' and exists (
        select 1 from public.trails tr
        where tr.id = entity_tags.entity_id
          and tr.owner_id = auth.uid()
      ))
      or (entity_type = 'arc_memory' and exists (
        select 1 from public.arc_memories am
        where am.id = entity_tags.entity_id
          and am.user_id = auth.uid()
      ))
    )
  );

create policy "Users update their own entity tags"
  on public.entity_tags for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "Users delete their own entity tags"
  on public.entity_tags for delete
  using (owner_id = auth.uid());
