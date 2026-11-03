begin;

-- AI plans may validly contain a single Mission for a small Quest.
alter table public.quests
  drop constraint if exists quests_estimated_mission_count_check;

alter table public.quests
  add constraint quests_estimated_mission_count_check
    check (estimated_mission_count is null or estimated_mission_count between 1 and 30) not valid;

alter table public.quests validate constraint quests_estimated_mission_count_check;

commit;
