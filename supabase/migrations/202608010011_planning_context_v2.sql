alter table public.weekly_availability
  add column if not exists companion_type text,
  add column if not exists setback_reasons text[] not null default '{}',
  add column if not exists approved_mission_history_summary text;

alter table public.weekly_availability
  drop constraint if exists weekly_availability_context_v2_bounds;
alter table public.weekly_availability
  add constraint weekly_availability_context_v2_bounds check (
    (companion_type is null or char_length(companion_type) <= 120) and
    cardinality(setback_reasons) <= 20 and
    (approved_mission_history_summary is null or
      char_length(approved_mission_history_summary) <= 500)
  );
