begin;

create table public.guild_quest_publications (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 160),
  summary text not null check (char_length(summary) between 1 and 2000),
  author_display_name text not null check (char_length(author_display_name) between 1 and 80),
  tags text[] not null default '{}'::text[] check (cardinality(tags) <= 20),
  difficulty_score integer check (difficulty_score between 1 and 5),
  estimated_duration_days integer check (estimated_duration_days between 1 and 36500),
  estimated_cost_label text check (estimated_cost_label is null or char_length(estimated_cost_label) <= 120),
  copy_count integer not null default 0 check (copy_count >= 0),
  completion_count integer not null default 0 check (completion_count >= 0),
  average_completion_rate double precision not null default 0 check (average_completion_rate between 0 and 1),
  review_score double precision check (review_score between 1 and 5),
  review_count integer not null default 0 check (review_count >= 0),
  seeking_companions boolean not null default false,
  participant_count integer not null default 0 check (participant_count >= 0),
  visibility text not null check (visibility in ('unlisted', 'public')),
  moderation_status text not null default 'pending' check (moderation_status in ('pending', 'approved', 'rejected')),
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.guild_quest_publication_owners (
  publication_id uuid primary key references public.guild_quest_publications(id) on delete cascade,
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  source_quest_id uuid not null references public.quests(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (owner_id, source_quest_id)
);

create table public.guild_mission_publications (
  id uuid primary key default gen_random_uuid(),
  quest_publication_id uuid not null references public.guild_quest_publications(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160),
  purpose text not null check (char_length(purpose) between 1 and 1200),
  order_index integer not null check (order_index >= 0),
  estimated_duration_days integer check (estimated_duration_days between 1 and 36500),
  difficulty_score integer check (difficulty_score between 1 and 5),
  tags text[] not null default '{}'::text[] check (cardinality(tags) <= 20),
  moderation_status text not null default 'pending' check (moderation_status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.guild_mission_publication_owners (
  mission_publication_id uuid primary key references public.guild_mission_publications(id) on delete cascade,
  owner_id uuid not null references public.user_profiles(id) on delete cascade,
  source_mission_id uuid not null references public.missions(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (owner_id, source_mission_id)
);

create table public.guild_quest_copy_events (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references public.guild_quest_publications(id) on delete cascade,
  copier_id uuid not null references public.user_profiles(id) on delete cascade,
  destination_quest_id uuid not null references public.quests(id) on delete cascade,
  include_missions boolean not null,
  arc_optimization_requested boolean not null,
  idempotency_key text not null check (char_length(idempotency_key) between 8 and 120),
  created_at timestamptz not null default now(),
  unique (copier_id, idempotency_key)
);

create index guild_quest_publications_discovery_idx
  on public.guild_quest_publications(moderation_status, visibility, published_at desc);
create index guild_quest_publications_tags_idx
  on public.guild_quest_publications using gin(tags);
create index guild_mission_publications_quest_idx
  on public.guild_mission_publications(quest_publication_id, order_index);

alter table public.guild_quest_publications enable row level security;
alter table public.guild_quest_publication_owners enable row level security;
alter table public.guild_mission_publications enable row level security;
alter table public.guild_mission_publication_owners enable row level security;
alter table public.guild_quest_copy_events enable row level security;

create policy "Guild Discovery reads approved public snapshots" on public.guild_quest_publications
  for select using (
    (visibility = 'public' and moderation_status = 'approved')
    or exists (
      select 1 from public.guild_quest_publication_owners ownership
      where ownership.publication_id = id and ownership.owner_id = auth.uid()
    )
  );

create policy "Guild publication ownership is owner private" on public.guild_quest_publication_owners
  for select using (owner_id = auth.uid());

create policy "Guild Mission Discovery follows approved publication" on public.guild_mission_publications
  for select using (
    (
      moderation_status = 'approved'
      and exists (
        select 1 from public.guild_quest_publications publication
        where publication.id = quest_publication_id
          and publication.visibility = 'public'
          and publication.moderation_status = 'approved'
      )
    )
    or exists (
      select 1 from public.guild_mission_publication_owners ownership
      where ownership.mission_publication_id = id and ownership.owner_id = auth.uid()
    )
  );

create policy "Guild Mission ownership is owner private" on public.guild_mission_publication_owners
  for select using (owner_id = auth.uid());

create policy "Guild copy events are copier private" on public.guild_quest_copy_events
  for select using (copier_id = auth.uid());

create or replace function public.publish_guild_quest(
  p_quest_id uuid,
  p_summary text,
  p_tags text[] default '{}'::text[],
  p_visibility text default 'public',
  p_seeking_companions boolean default false
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor_id uuid := auth.uid();
  publication_id uuid;
  source_quest public.quests%rowtype;
  display_name text;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if p_visibility not in ('unlisted', 'public') then raise exception 'invalid visibility'; end if;
  if char_length(trim(p_summary)) not between 1 and 2000 then raise exception 'invalid summary'; end if;
  if cardinality(coalesce(p_tags, '{}'::text[])) > 20 then raise exception 'too many tags'; end if;

  select * into source_quest from public.quests
    where id = p_quest_id and owner_id = actor_id;
  if not found then raise exception 'Quest not found'; end if;

  select coalesce(nullif(trim(nickname), ''), 'Navigator') into display_name
    from public.user_profiles where id = actor_id;

  select ownership.publication_id into publication_id
    from public.guild_quest_publication_owners ownership
    where ownership.owner_id = actor_id and ownership.source_quest_id = p_quest_id;

  if publication_id is null then
    insert into public.guild_quest_publications (
      title, summary, author_display_name, tags, difficulty_score,
      estimated_duration_days, estimated_cost_label, seeking_companions, visibility
    ) values (
      source_quest.title, trim(p_summary), coalesce(display_name, 'Navigator'), coalesce(p_tags, '{}'::text[]),
      source_quest.difficulty_score, source_quest.estimated_duration_days,
      source_quest.estimated_cost, p_seeking_companions, p_visibility
    ) returning id into publication_id;

    insert into public.guild_quest_publication_owners(publication_id, owner_id, source_quest_id)
      values (publication_id, actor_id, p_quest_id);
  else
    update public.guild_quest_publications set
      title = source_quest.title,
      summary = trim(p_summary),
      author_display_name = coalesce(display_name, 'Navigator'),
      tags = coalesce(p_tags, '{}'::text[]),
      difficulty_score = source_quest.difficulty_score,
      estimated_duration_days = source_quest.estimated_duration_days,
      estimated_cost_label = source_quest.estimated_cost,
      seeking_companions = p_seeking_companions,
      visibility = p_visibility,
      moderation_status = 'pending',
      updated_at = now()
    where id = publication_id;
  end if;
  return publication_id;
end;
$$;

create or replace function public.publish_guild_mission(
  p_publication_id uuid,
  p_mission_id uuid,
  p_purpose text,
  p_tags text[] default '{}'::text[]
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor_id uuid := auth.uid();
  mission_publication_id uuid;
  source_mission public.missions%rowtype;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if char_length(trim(p_purpose)) not between 1 and 1200 then raise exception 'invalid purpose'; end if;
  if cardinality(coalesce(p_tags, '{}'::text[])) > 20 then raise exception 'too many tags'; end if;
  if not exists (
    select 1 from public.guild_quest_publication_owners
    where publication_id = p_publication_id and owner_id = actor_id
  ) then raise exception 'Publication not found'; end if;

  select mission.* into source_mission
    from public.missions mission
    join public.quests quest on quest.id = mission.quest_id
    join public.guild_quest_publication_owners ownership
      on ownership.source_quest_id = quest.id and ownership.publication_id = p_publication_id
    where mission.id = p_mission_id and quest.owner_id = actor_id;
  if not found then raise exception 'Mission not found'; end if;

  select ownership.mission_publication_id into mission_publication_id
    from public.guild_mission_publication_owners ownership
    where ownership.owner_id = actor_id and ownership.source_mission_id = p_mission_id;

  if mission_publication_id is null then
    insert into public.guild_mission_publications (
      quest_publication_id, title, purpose, order_index,
      estimated_duration_days, difficulty_score, tags
    ) values (
      p_publication_id, source_mission.title, trim(p_purpose), source_mission.sort_order,
      source_mission.estimated_duration_days, source_mission.difficulty_score,
      coalesce(p_tags, '{}'::text[])
    ) returning id into mission_publication_id;
    insert into public.guild_mission_publication_owners(mission_publication_id, owner_id, source_mission_id)
      values (mission_publication_id, actor_id, p_mission_id);
  else
    update public.guild_mission_publications set
      title = source_mission.title,
      purpose = trim(p_purpose),
      order_index = source_mission.sort_order,
      estimated_duration_days = source_mission.estimated_duration_days,
      difficulty_score = source_mission.difficulty_score,
      tags = coalesce(p_tags, '{}'::text[]),
      moderation_status = 'pending',
      updated_at = now()
    where id = mission_publication_id;
  end if;
  return mission_publication_id;
end;
$$;

create or replace function public.unpublish_guild_quest(p_publication_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  update public.guild_quest_publications set visibility = 'unlisted', updated_at = now()
    where id = p_publication_id and exists (
      select 1 from public.guild_quest_publication_owners ownership
      where ownership.publication_id = p_publication_id and ownership.owner_id = auth.uid()
    );
  if not found then raise exception 'Publication not found'; end if;
end;
$$;

create or replace function public.record_guild_quest_copy(
  p_publication_id uuid,
  p_destination_quest_id uuid,
  p_include_missions boolean,
  p_arc_optimization_requested boolean,
  p_idempotency_key text
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor_id uuid := auth.uid();
  copy_event_id uuid;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if char_length(p_idempotency_key) not between 8 and 120 then raise exception 'invalid idempotency key'; end if;
  if not exists (
    select 1 from public.guild_quest_publications
    where id = p_publication_id and visibility = 'public' and moderation_status = 'approved'
  ) then raise exception 'Publication not available'; end if;
  if not exists (
    select 1 from public.quests where id = p_destination_quest_id and owner_id = actor_id
  ) then raise exception 'Destination Quest not found'; end if;

  insert into public.guild_quest_copy_events (
    publication_id, copier_id, destination_quest_id, include_missions,
    arc_optimization_requested, idempotency_key
  ) values (
    p_publication_id, actor_id, p_destination_quest_id, p_include_missions,
    p_arc_optimization_requested, p_idempotency_key
  ) on conflict (copier_id, idempotency_key) do nothing
  returning id into copy_event_id;

  if copy_event_id is not null then
    update public.guild_quest_publications set copy_count = copy_count + 1
      where id = p_publication_id;
  else
    select id into copy_event_id from public.guild_quest_copy_events
      where copier_id = actor_id and idempotency_key = p_idempotency_key;
  end if;
  return copy_event_id;
end;
$$;

revoke all on public.guild_quest_publications,
  public.guild_quest_publication_owners,
  public.guild_mission_publications,
  public.guild_mission_publication_owners,
  public.guild_quest_copy_events from anon, authenticated;

grant select on public.guild_quest_publications, public.guild_mission_publications to anon, authenticated;
grant select on public.guild_quest_publication_owners,
  public.guild_mission_publication_owners,
  public.guild_quest_copy_events to authenticated;

revoke all on function public.publish_guild_quest(uuid, text, text[], text, boolean) from public;
revoke all on function public.publish_guild_mission(uuid, uuid, text, text[]) from public;
revoke all on function public.unpublish_guild_quest(uuid) from public;
revoke all on function public.record_guild_quest_copy(uuid, uuid, boolean, boolean, text) from public;
grant execute on function public.publish_guild_quest(uuid, text, text[], text, boolean) to authenticated;
grant execute on function public.publish_guild_mission(uuid, uuid, text, text[]) to authenticated;
grant execute on function public.unpublish_guild_quest(uuid) to authenticated;
grant execute on function public.record_guild_quest_copy(uuid, uuid, boolean, boolean, text) to authenticated;

comment on table public.guild_quest_publications is
  'Moderated, public-safe Guild Discovery snapshots. Ownership is intentionally stored separately.';
comment on table public.guild_quest_copy_events is
  'Private derivation events; source authors receive aggregate counts only.';

commit;
