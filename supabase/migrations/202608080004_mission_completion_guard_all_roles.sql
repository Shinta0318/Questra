-- QST-278 follow-up: completion integrity applies to legacy and new Missions.
begin;

create or replace function public.guard_mission_completion()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if (tg_op = 'INSERT' or old.status is distinct from 'completed' or old.success_confirmed_at is null)
    and (new.status = 'completed' or new.success_confirmed_at is not null)
    and coalesce(current_setting('questra.mission_completion_rpc', true), '') <> 'on' then
    raise exception 'mission_completion_requires_rpc';
  end if;
  return new;
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

commit;
