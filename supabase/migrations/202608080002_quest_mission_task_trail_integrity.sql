-- QST-278: enforce the Quest -> Mission -> Task -> Trail hierarchy in the DB.
begin;

alter table public.trails
  add column if not exists task_id uuid references public.tasks(id) on delete set null;

create index if not exists trails_task_created_idx
  on public.trails(task_id, created_at desc) where task_id is not null;

create or replace function public.validate_task_hierarchy()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_owner uuid;
  v_quest uuid;
  v_dependency uuid;
begin
  select q.owner_id, m.quest_id into v_owner, v_quest
  from public.missions m
  join public.quests q on q.id = m.quest_id
  where m.id = new.mission_id;
  if v_owner is null or v_owner <> new.owner_id or v_quest <> new.quest_id then
    raise exception 'task_parent_mismatch';
  end if;

  foreach v_dependency in array coalesce(new.dependency_ids, '{}'::uuid[]) loop
    if v_dependency = new.id or not exists (
      select 1 from public.tasks d
      where d.id = v_dependency
        and d.owner_id = new.owner_id
        and d.quest_id = new.quest_id
        and d.mission_id = new.mission_id
    ) then
      raise exception 'task_dependency_mismatch';
    end if;
  end loop;

  if exists (
    with recursive dependency_walk(id) as (
      select unnest(coalesce(new.dependency_ids, '{}'::uuid[]))
      union
      select unnest(coalesce(t.dependency_ids, '{}'::uuid[]))
      from public.tasks t join dependency_walk w on t.id = w.id
    )
    select 1 from dependency_walk where id = new.id
  ) then
    raise exception 'task_dependency_cycle';
  end if;
  return new;
end;
$$;

drop trigger if exists tasks_validate_hierarchy on public.tasks;
create trigger tasks_validate_hierarchy
before insert or update of owner_id, quest_id, mission_id, dependency_ids
on public.tasks for each row execute function public.validate_task_hierarchy();

create or replace function public.validate_trail_hierarchy()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_quest_owner uuid;
  v_mission_quest uuid;
  v_task_owner uuid;
  v_task_quest uuid;
  v_task_mission uuid;
begin
  if new.quest_id is not null then
    select owner_id into v_quest_owner from public.quests where id = new.quest_id;
    if v_quest_owner is null or v_quest_owner <> new.owner_id then
      raise exception 'trail_quest_mismatch';
    end if;
  end if;

  if new.mission_id is not null then
    select quest_id into v_mission_quest from public.missions where id = new.mission_id;
    if v_mission_quest is null or new.quest_id is null or v_mission_quest <> new.quest_id then
      raise exception 'trail_mission_mismatch';
    end if;
  end if;

  if new.task_id is not null then
    select owner_id, quest_id, mission_id
      into v_task_owner, v_task_quest, v_task_mission
    from public.tasks where id = new.task_id;
    if v_task_owner is null
      or v_task_owner <> new.owner_id
      or new.quest_id is null
      or new.mission_id is null
      or v_task_quest <> new.quest_id
      or v_task_mission <> new.mission_id then
      raise exception 'trail_task_mismatch';
    end if;
  end if;

  if new.trail_type = 'mission_record' and new.mission_id is null then
    raise exception 'mission_trail_requires_mission';
  end if;
  return new;
end;
$$;

drop trigger if exists trails_validate_hierarchy on public.trails;
create trigger trails_validate_hierarchy
before insert or update of owner_id, quest_id, mission_id, task_id, trail_type
on public.trails for each row execute function public.validate_trail_hierarchy();

create or replace function public.guard_mission_completion()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if new.hierarchy_role = 'outcome'
    and (tg_op = 'INSERT' or old.status is distinct from 'completed' or old.success_confirmed_at is null)
    and (new.status = 'completed' or new.success_confirmed_at is not null)
    and coalesce(current_setting('questra.mission_completion_rpc', true), '') <> 'on' then
    raise exception 'mission_completion_requires_rpc';
  end if;
  return new;
end;
$$;

drop trigger if exists missions_guard_completion on public.missions;
create trigger missions_guard_completion
before insert or update on public.missions
for each row execute function public.guard_mission_completion();

create or replace function public.recalculate_quest_hierarchy_progress(p_quest_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_owner uuid; v_quest_progress numeric;
begin
  select owner_id into v_owner from public.quests where id = p_quest_id;
  if v_owner is null then return; end if;
  if auth.uid() is not null and auth.uid() <> v_owner then raise exception 'quest_not_owned'; end if;

  update public.missions m set
    progress_percent = stats.progress,
    status = case when stats.task_total > 0 and stats.required_incomplete = 0 and m.success_confirmed_at is not null then 'completed' else 'todo' end,
    success_confirmed_at = case when stats.task_total > 0 and stats.required_incomplete = 0 then m.success_confirmed_at else null end,
    completed_at = case when stats.task_total > 0 and stats.required_incomplete = 0 and m.success_confirmed_at is not null then coalesce(m.completed_at, now()) else null end,
    updated_at = now()
  from (
    select mission_id,
      count(*) as task_total,
      count(*) filter (where required and status <> 'completed') as required_incomplete,
      case
        when count(*) = 0 then 0
        when count(*) filter (where required) = 0 then 100
        else round(100.0 * count(*) filter (where required and status = 'completed') / count(*) filter (where required))::integer
      end as progress
    from public.tasks where quest_id = p_quest_id group by mission_id
  ) stats where m.id = stats.mission_id and m.hierarchy_role = 'outcome';

  select case when count(*) filter (where required and hierarchy_role = 'outcome' and route_state = 'active') = 0 then 0
    else count(*) filter (where required and hierarchy_role = 'outcome' and route_state = 'active' and status = 'completed')::numeric /
      count(*) filter (where required and hierarchy_role = 'outcome' and route_state = 'active') end
  into v_quest_progress from public.missions where quest_id = p_quest_id;
  update public.quests set progress = coalesce(v_quest_progress, 0), updated_at = now() where id = p_quest_id;
end;
$$;

create or replace function public.confirm_mission_outcome(p_mission_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_mission public.missions%rowtype;
  v_task_total integer;
  v_required_incomplete integer;
begin
  select m.* into v_mission
  from public.missions m join public.quests q on q.id = m.quest_id
  where m.id = p_mission_id and q.owner_id = auth.uid()
  for update of m;
  if not found then raise exception 'mission_not_owned'; end if;
  if v_mission.hierarchy_role <> 'outcome' then raise exception 'mission_not_confirmable'; end if;

  perform 1 from public.tasks where mission_id = p_mission_id for share;
  select count(*), count(*) filter (where required and status <> 'completed')
    into v_task_total, v_required_incomplete
  from public.tasks where mission_id = p_mission_id;
  if v_task_total = 0 then raise exception 'mission_requires_task'; end if;
  if v_required_incomplete > 0 then raise exception 'required_tasks_incomplete'; end if;

  perform set_config('questra.mission_completion_rpc', 'on', true);
  update public.missions set
    progress_percent = 100,
    status = 'completed',
    success_confirmed_at = coalesce(success_confirmed_at, now()),
    completed_at = coalesce(completed_at, now()),
    updated_at = now()
  where id = p_mission_id
  returning * into v_mission;
  perform public.recalculate_quest_hierarchy_progress(v_mission.quest_id);
  return jsonb_build_object(
    'mission_id', v_mission.id,
    'quest_id', v_mission.quest_id,
    'status', v_mission.status,
    'success_confirmed_at', v_mission.success_confirmed_at
  );
end;
$$;

revoke all on function public.confirm_mission_outcome(uuid) from public, anon;
grant execute on function public.confirm_mission_outcome(uuid) to authenticated;

comment on function public.confirm_mission_outcome(uuid) is
  'Owner-only Mission outcome confirmation after all required Tasks are complete.';

commit;
