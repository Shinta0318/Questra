alter table public.quests
  add column if not exists quest_understanding jsonb;

alter table public.quests
  drop constraint if exists quests_understanding_object_check;

alter table public.quests
  add constraint quests_understanding_object_check
  check (quest_understanding is null or jsonb_typeof(quest_understanding) = 'object')
  not valid;

alter table public.quests validate constraint quests_understanding_object_check;
