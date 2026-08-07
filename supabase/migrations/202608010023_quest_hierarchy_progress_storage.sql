begin;

alter table public.quests
  add column if not exists progress numeric(4,3) not null default 0;

alter table public.quests
  add constraint quests_progress_check check (progress between 0 and 1) not valid;
alter table public.quests validate constraint quests_progress_check;

comment on column public.quests.progress is
  'Derived from completed required outcome Missions. Clients must not use it as an independent completion source.';

commit;
