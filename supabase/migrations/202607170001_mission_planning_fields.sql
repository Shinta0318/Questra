alter table public.missions
  add column if not exists is_today boolean not null default false;

create index if not exists idx_missions_quest_sort_order
  on public.missions (quest_id, sort_order);

create index if not exists idx_missions_today
  on public.missions (quest_id, is_today)
  where is_today = true;
