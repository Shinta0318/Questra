alter table public.weekly_availability
  add column if not exists planning_consent_granted boolean not null default false,
  add column if not exists budget_label text,
  add column if not exists location text,
  add column if not exists experience text,
  add column if not exists available_resources text[] not null default '{}',
  add column if not exists preferences text[] not null default '{}';

alter table public.weekly_availability
  drop constraint if exists weekly_availability_planning_text_lengths,
  add constraint weekly_availability_planning_text_lengths check (
    char_length(coalesce(budget_label, '')) <= 120 and
    char_length(coalesce(location, '')) <= 120 and
    char_length(coalesce(experience, '')) <= 240 and
    cardinality(available_resources) <= 20 and
    cardinality(preferences) <= 20
  );
