begin;

alter table public.quests
  add column if not exists requested_target_month date,
  add column if not exists effort_estimate jsonb,
  add column if not exists feasibility_estimate jsonb;

alter table public.missions
  add column if not exists effort_estimate jsonb;

alter table public.quests
  add constraint quests_requested_target_month_first_day_check
  check (
    requested_target_month is null or
    requested_target_month = date_trunc('month', requested_target_month)::date
  ) not valid;

alter table public.quests
  validate constraint quests_requested_target_month_first_day_check;

comment on column public.quests.requested_target_month is
  'Owner-requested yyyy/MM target stored as the first day. Replanning must not silently overwrite it.';
comment on column public.quests.effort_estimate is
  'Versioned guidance: difficulty band, active effort, calendar duration, confidence, and rationale.';
comment on column public.quests.feasibility_estimate is
  'Versioned comparison between requested target and estimated completion window.';

commit;
