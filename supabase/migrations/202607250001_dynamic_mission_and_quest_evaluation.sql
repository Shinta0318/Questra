begin;

alter table public.missions
  add column if not exists parent_mission_id uuid references public.missions(id) on delete set null,
  add column if not exists dependency_ids uuid[] not null default '{}'::uuid[],
  add column if not exists priority text not null default 'normal',
  add column if not exists category text not null default '実行',
  add column if not exists estimated_cost_label text,
  add column if not exists reference_hints text[] not null default '{}'::text[],
  add column if not exists enterprise_support_hints text[] not null default '{}'::text[],
  add column if not exists difficulty_score integer,
  add column if not exists estimated_duration_days integer;

alter table public.missions
  add constraint missions_priority_check
    check (priority in ('low', 'normal', 'high', 'critical')) not valid,
  add constraint missions_difficulty_score_check
    check (difficulty_score is null or difficulty_score between 1 and 5) not valid,
  add constraint missions_estimated_duration_check
    check (estimated_duration_days is null or estimated_duration_days between 1 and 3650) not valid,
  add constraint missions_parent_not_self_check
    check (parent_mission_id is null or parent_mission_id <> id) not valid,
  add constraint missions_dependency_not_self_check
    check (not (id = any(dependency_ids))) not valid;

alter table public.missions validate constraint missions_priority_check;
alter table public.missions validate constraint missions_difficulty_score_check;
alter table public.missions validate constraint missions_estimated_duration_check;
alter table public.missions validate constraint missions_parent_not_self_check;
alter table public.missions validate constraint missions_dependency_not_self_check;

create index if not exists missions_parent_mission_id_idx
  on public.missions(parent_mission_id);

create or replace function public.validate_mission_graph_scope()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.parent_mission_id is not null and not exists (
    select 1 from public.missions parent
    where parent.id = new.parent_mission_id and parent.quest_id = new.quest_id
  ) then
    raise exception 'parent mission must belong to the same quest';
  end if;

  if exists (
    select 1 from unnest(new.dependency_ids) dependency_id
    left join public.missions dependency on dependency.id = dependency_id
    where dependency.id is null or dependency.quest_id <> new.quest_id
  ) then
    raise exception 'mission dependencies must belong to the same quest';
  end if;
  return new;
end;
$$;

drop trigger if exists validate_mission_graph_scope on public.missions;
create constraint trigger validate_mission_graph_scope
after insert or update of quest_id, parent_mission_id, dependency_ids
on public.missions
deferrable initially immediate
for each row execute function public.validate_mission_graph_scope();

alter table public.quests
  add column if not exists quest_evaluation jsonb,
  add column if not exists difficulty_score integer,
  add column if not exists estimated_duration_days integer,
  add column if not exists estimated_cost text,
  add column if not exists estimated_success_rate double precision,
  add column if not exists estimated_mission_count integer,
  add column if not exists evaluation_version text,
  add column if not exists evaluated_at timestamptz,
  add column if not exists recommended_start_date date,
  add column if not exists risk_summary text;

alter table public.quests
  add constraint quests_ai_difficulty_score_check
    check (difficulty_score is null or difficulty_score between 1 and 5) not valid,
  add constraint quests_estimated_duration_check
    check (estimated_duration_days is null or estimated_duration_days between 1 and 36500) not valid,
  add constraint quests_estimated_success_rate_check
    check (estimated_success_rate is null or estimated_success_rate between 0 and 1) not valid,
  add constraint quests_estimated_mission_count_check
    check (estimated_mission_count is null or estimated_mission_count between 3 and 30) not valid;

alter table public.quests validate constraint quests_ai_difficulty_score_check;
alter table public.quests validate constraint quests_estimated_duration_check;
alter table public.quests validate constraint quests_estimated_success_rate_check;
alter table public.quests validate constraint quests_estimated_mission_count_check;

comment on column public.quests.quest_evaluation is
  'Versioned Arc evaluation snapshot. AI-derived values are read-only in owner UI.';
comment on column public.missions.enterprise_support_hints is
  'Generic transparent support categories, not confirmed company offers.';

commit;
