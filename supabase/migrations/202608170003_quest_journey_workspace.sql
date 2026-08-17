-- QST-332: Quest Journey hierarchy integrity and atomic Task operations.

alter table public.tasks
  add column if not exists origin text,
  add column if not exists version integer not null default 1,
  add column if not exists today_excluded_until date,
  add column if not exists source_proposal_id uuid;

update public.tasks
set origin = case generated_by
  when 'arc' then 'arc_suggestion'
  when 'system' then 'system'
  when 'migration' then 'migration'
  else 'user'
end
where origin is null;

alter table public.tasks alter column origin set default 'user';
alter table public.tasks alter column origin set not null;

do $$
declare v_constraint text;
begin
  select conname into v_constraint
  from pg_constraint
  where conrelid = 'public.tasks'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%status%pending%ready%';
  if v_constraint is not null then
    execute format('alter table public.tasks drop constraint %I', v_constraint);
  end if;
end $$;

alter table public.tasks
  add constraint tasks_status_journey_check check (
    status in (
      'pending', 'ready', 'in_progress', 'completed', 'deferred',
      'skipped', 'blocked', 'cancelled'
    )
  ) not valid,
  add constraint tasks_origin_check check (
    origin in (
      'user', 'arc_suggestion', 'copied', 'enterprise_offer_accepted',
      'system', 'migration'
    )
  ) not valid,
  add constraint tasks_version_positive check (version > 0) not valid;

alter table public.tasks validate constraint tasks_status_journey_check;
alter table public.tasks validate constraint tasks_origin_check;
alter table public.tasks validate constraint tasks_version_positive;

create or replace function public.validate_task_journey_parent()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid;
  v_quest_id uuid;
begin
  select q.owner_id, m.quest_id
    into v_owner, v_quest_id
  from public.missions m
  join public.quests q on q.id = m.quest_id
  where m.id = new.mission_id;

  if v_owner is null or v_owner <> new.owner_id then
    raise exception 'task_parent_not_owned';
  end if;
  if v_quest_id <> new.quest_id then
    raise exception 'task_parent_quest_mismatch';
  end if;
  if new.origin = 'enterprise_offer_accepted'
     and new.source_proposal_id is null then
    raise exception 'enterprise_task_requires_accepted_proposal';
  end if;
  return new;
end;
$$;

drop trigger if exists tasks_validate_journey_parent on public.tasks;
create trigger tasks_validate_journey_parent
before insert or update of owner_id, quest_id, mission_id, origin, source_proposal_id
on public.tasks
for each row execute function public.validate_task_journey_parent();

create or replace function public.complete_task_journey(
  p_task_id uuid,
  p_operation_id text,
  p_expected_version integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_task public.tasks%rowtype;
  v_award jsonb;
begin
  if v_actor is null then raise exception 'authentication_required'; end if;
  if nullif(btrim(p_operation_id), '') is null then
    raise exception 'operation_id_required';
  end if;

  select * into v_task
  from public.tasks
  where id = p_task_id
  for update;

  if v_task.id is null or v_task.owner_id <> v_actor then
    raise exception 'task_not_owned';
  end if;
  if p_expected_version is not null and v_task.version <> p_expected_version then
    raise exception 'task_version_conflict';
  end if;

  if v_task.status = 'completed' then
    return jsonb_build_object(
      'task_id', v_task.id,
      'status', v_task.status,
      'version', v_task.version,
      'already_applied', true
    );
  end if;
  if v_task.status in ('skipped', 'blocked', 'cancelled', 'deferred') then
    raise exception 'task_not_completable';
  end if;
  if exists (
    select 1
    from unnest(v_task.dependency_ids) dependency_id
    left join public.tasks dependency on dependency.id = dependency_id
    where dependency.id is null
       or dependency.owner_id <> v_actor
       or dependency.mission_id <> v_task.mission_id
       or dependency.status <> 'completed'
  ) then
    raise exception 'task_dependencies_incomplete';
  end if;

  update public.tasks
  set status = 'completed',
      completed_at = coalesce(completed_at, now()),
      version = version + 1,
      updated_at = now()
  where id = p_task_id
  returning * into v_task;

  insert into public.task_progress_events (
    owner_id, quest_id, mission_id, task_id, event_name, event_key, metadata
  ) values (
    v_actor, v_task.quest_id, v_task.mission_id, v_task.id,
    'task_completed', 'journey:' || p_operation_id,
    jsonb_build_object('source', 'quest_journey_workspace')
  ) on conflict (owner_id, event_key) do nothing;

  v_award := public.award_stardust('task_completed', p_task_id);

  return jsonb_build_object(
    'task_id', v_task.id,
    'status', v_task.status,
    'completed_at', v_task.completed_at,
    'version', v_task.version,
    'already_applied', false,
    'progression', v_award
  );
end;
$$;

create or replace function public.reorder_mission_tasks(
  p_mission_id uuid,
  p_task_ids uuid[],
  p_operation_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_count integer;
begin
  if v_actor is null then raise exception 'authentication_required'; end if;
  if nullif(btrim(p_operation_id), '') is null then
    raise exception 'operation_id_required';
  end if;
  if coalesce(array_length(p_task_ids, 1), 0) = 0 then
    raise exception 'task_ids_required';
  end if;
  if array_length(p_task_ids, 1) <> (
    select count(distinct id) from unnest(p_task_ids) id
  ) then raise exception 'duplicate_task_ids'; end if;

  select count(*) into v_count
  from public.tasks
  where mission_id = p_mission_id
    and owner_id = v_actor
    and id = any(p_task_ids);
  if v_count <> array_length(p_task_ids, 1) then
    raise exception 'task_reorder_scope_mismatch';
  end if;

  update public.tasks task
  set order_index = ordered.position - 1,
      version = task.version + 1,
      updated_at = now()
  from unnest(p_task_ids) with ordinality ordered(id, position)
  where task.id = ordered.id
    and task.mission_id = p_mission_id
    and task.owner_id = v_actor;

  return jsonb_build_object(
    'mission_id', p_mission_id,
    'updated_count', v_count,
    'operation_id', p_operation_id
  );
end;
$$;

revoke all on function public.complete_task_journey(uuid, text, integer) from public, anon;
revoke all on function public.reorder_mission_tasks(uuid, uuid[], text) from public, anon;
grant execute on function public.complete_task_journey(uuid, text, integer) to authenticated;
grant execute on function public.reorder_mission_tasks(uuid, uuid[], text) to authenticated;
