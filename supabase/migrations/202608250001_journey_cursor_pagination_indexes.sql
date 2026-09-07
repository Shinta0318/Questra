-- QST-348: keyset pagination indexes for the core journey data plane.
-- Cursor values are never trusted as ownership evidence. Queries must filter
-- by auth-owned parent rows first, then apply these ordered indexes.

begin;

create index if not exists quests_owner_created_cursor_idx
  on public.quests(owner_id, created_at desc, id desc);

create index if not exists missions_quest_order_cursor_idx
  on public.missions(quest_id, order_index, id);

create index if not exists tasks_owner_quest_mission_order_cursor_idx
  on public.tasks(owner_id, quest_id, mission_id, order_index, id);

create index if not exists tasks_owner_created_cursor_idx
  on public.tasks(owner_id, created_at desc, id desc);

create index if not exists trails_owner_created_cursor_idx
  on public.trails(owner_id, created_at desc, id desc);

create index if not exists trails_owner_quest_created_cursor_idx
  on public.trails(owner_id, quest_id, created_at desc, id desc)
  where quest_id is not null;

create index if not exists trails_owner_mission_created_cursor_idx
  on public.trails(owner_id, mission_id, created_at desc, id desc)
  where mission_id is not null;

create index if not exists media_owner_related_created_cursor_idx
  on public.media(owner_id, related_table, related_id, created_at desc, id desc);

create index if not exists guild_posts_guild_created_cursor_idx
  on public.guild_posts(guild_id, created_at desc, id desc);

commit;
