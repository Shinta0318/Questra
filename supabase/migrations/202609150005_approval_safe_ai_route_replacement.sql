-- QST-456: approval-safe AI route replacement after manual Mission creation.

create or replace function public.approve_quest_plan_preview(
  p_preview_id uuid,
  p_approval_token uuid
) returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_preview public.quest_plan_previews%rowtype;
  v_route_id uuid;
  v_route_version integer;
  v_mission jsonb;
  v_task jsonb;
  v_base_mission jsonb;
  v_ids jsonb := '{}'::jsonb;
  v_task_ids jsonb := '{}'::jsonb;
  v_mission_id uuid;
  v_task_id uuid;
  v_current_mission_id uuid;
  v_dependency text;
  v_application_mode text;
  v_base_count integer := 0;
  v_current_count integer := 0;
  v_carried_count integer := 0;
  v_count integer := 0;
  v_task_count integer := 0;
begin
  select * into v_preview
  from public.quest_plan_previews
  where id = p_preview_id
  for update;

  if not found or v_preview.owner_id <> auth.uid() then
    raise exception 'preview_not_found';
  end if;
  if v_preview.status = 'approved' then
    return jsonb_build_object(
      'preview_id', v_preview.id,
      'status', 'approved',
      'idempotent', true
    );
  end if;
  if v_preview.status <> 'pending' or v_preview.expires_at <= now() then
    raise exception 'preview_not_approvable';
  end if;
  if v_preview.approval_token <> p_approval_token then
    raise exception 'approval_token_invalid';
  end if;
  if v_preview.plan_payload->'routeMissionPlan' is null then
    raise exception 'legacy_preview_requires_regeneration';
  end if;
  perform 1
  from public.quests
  where id = v_preview.quest_id and owner_id = auth.uid()
  for update;
  if not found then
    raise exception 'quest_not_owned';
  end if;

  v_application_mode := v_preview.plan_payload #>> '{routeApplication,applicationMode}';
  if v_application_mode is null
    or v_application_mode not in ('initial', 'replace_remaining') then
    raise exception 'route_application_missing';
  end if;

  perform 1
  from public.missions
  where quest_id = v_preview.quest_id and route_state <> 'removed'
  for update;

  select count(*) into v_current_count
  from public.missions
  where quest_id = v_preview.quest_id and route_state <> 'removed';

  v_base_count := jsonb_array_length(
    coalesce(v_preview.plan_payload #> '{routeApplication,baseMissions}', '[]'::jsonb)
  );

  if v_application_mode = 'initial' then
    if v_base_count <> 0 or v_current_count <> 0 then
      raise exception 'route_changed_since_preview';
    end if;
  else
    if v_base_count = 0 or v_base_count <> v_current_count then
      raise exception 'route_changed_since_preview';
    end if;

    for v_base_mission in
      select value
      from jsonb_array_elements(
        coalesce(v_preview.plan_payload #> '{routeApplication,baseMissions}', '[]'::jsonb)
      )
    loop
      if not exists(
        select 1
        from public.missions
        where id = (v_base_mission->>'id')::uuid
          and quest_id = v_preview.quest_id
          and route_state <> 'removed'
          and status = v_base_mission->>'status'
          and updated_at = (v_base_mission->>'updatedAt')::timestamptz
      ) then
        raise exception 'route_changed_since_preview';
      end if;
    end loop;
  end if;

  update public.route_versions
  set status = 'superseded'
  where quest_id = v_preview.quest_id and status = 'active';

  select coalesce(max(version_number), 0) + 1 into v_route_version
  from public.route_versions
  where quest_id = v_preview.quest_id;

  insert into public.route_versions(
    quest_id, version_number, status, generated_by, generation_reason,
    ai_model, prompt_version, route_snapshot, approved_at, approved_by
  ) values (
    v_preview.quest_id,
    v_route_version,
    'active',
    'arc',
    case when v_application_mode = 'replace_remaining'
      then 'approved_ai_remaining_route_replacement'
      else 'approved_quest_hierarchy_plan'
    end,
    'gemini',
    coalesce(v_preview.plan_payload #>> '{routeMissionPlan,planVersion}', '1'),
    jsonb_build_object(
      'applicationMode', v_application_mode,
      'baseMissionCount', v_base_count,
      'carriedCompletedMissionIds', coalesce(
        v_preview.plan_payload #> '{routeApplication,completedMissionIds}',
        '[]'::jsonb
      ),
      'missionOrder', v_preview.plan_payload #> '{routeMissionPlan,missions}'
    ),
    now(),
    auth.uid()
  ) returning id into v_route_id;

  if v_application_mode = 'replace_remaining' then
    update public.missions
    set route_state = 'removed', updated_at = now()
    where quest_id = v_preview.quest_id
      and route_state <> 'removed'
      and status <> 'completed';

    with carried as (
      select
        id,
        row_number() over (order by order_index, sort_order, created_at, id) - 1 as next_order
      from public.missions
      where quest_id = v_preview.quest_id
        and route_state <> 'removed'
        and status = 'completed'
    )
    update public.missions mission
    set
      route_id = v_route_id,
      sort_order = carried.next_order::integer,
      order_index = carried.next_order::integer,
      updated_at = now()
    from carried
    where mission.id = carried.id;

    select count(*) into v_carried_count
    from public.missions
    where quest_id = v_preview.quest_id
      and route_id = v_route_id
      and route_state <> 'removed'
      and status = 'completed';
    v_count := v_carried_count;
  end if;

  for v_mission in
    select value
    from jsonb_array_elements(v_preview.plan_payload #> '{routeMissionPlan,missions}')
  loop
    if exists(
      select 1
      from public.missions
      where quest_id = v_preview.quest_id
        and route_id = v_route_id
        and route_state <> 'removed'
        and status = 'completed'
        and lower(btrim(title)) = lower(btrim(v_mission->>'title'))
    ) then
      raise exception 'completed_mission_duplicate_in_plan';
    end if;

    insert into public.missions(
      quest_id, route_id, title, description, objective,
      success_condition, expected_outcome, done_condition, expected_output,
      estimated_duration_days, sort_order, order_index, required, weight,
      confidence, generated_by, generation_version, hierarchy_role
    ) values (
      v_preview.quest_id,
      v_route_id,
      v_mission->>'title',
      v_mission->>'objective',
      v_mission->>'objective',
      v_mission->>'successCondition',
      v_mission->>'expectedOutcome',
      v_mission->>'successCondition',
      v_mission->>'expectedOutcome',
      greatest(0, coalesce((v_mission->>'calendarDurationDays')::integer, 0)),
      v_count,
      v_count,
      coalesce((v_mission->>'required')::boolean, true),
      greatest(0.001, least(100, coalesce((v_mission->>'weight')::numeric, 1))),
      greatest(0, least(1, coalesce((v_mission->>'confidence')::double precision, 0.5))),
      'arc',
      'quest-hierarchy-3.1',
      'outcome'
    ) returning id into v_mission_id;
    v_ids := v_ids || jsonb_build_object(v_mission->>'clientId', v_mission_id);
    v_count := v_count + 1;
  end loop;

  for v_mission in
    select value
    from jsonb_array_elements(v_preview.plan_payload #> '{routeMissionPlan,missions}')
  loop
    for v_dependency in
      select value
      from jsonb_array_elements_text(coalesce(v_mission->'dependencies', '[]'::jsonb))
    loop
      if v_ids ? v_dependency then
        insert into public.mission_dependencies(mission_id, depends_on_mission_id)
        values(
          (v_ids->>(v_mission->>'clientId'))::uuid,
          (v_ids->>v_dependency)::uuid
        ) on conflict do nothing;
      end if;
    end loop;
  end loop;

  v_current_mission_id := (
    v_ids->>(v_preview.plan_payload #>> '{currentTaskPlan,missionClientId}')
  )::uuid;
  if v_current_mission_id is null then
    raise exception 'task_plan_mission_not_found';
  end if;

  for v_task in
    select value
    from jsonb_array_elements(v_preview.plan_payload #> '{currentTaskPlan,tasks}')
  loop
    insert into public.tasks(
      owner_id, quest_id, mission_id, title, action, purpose, done_condition,
      expected_output, estimated_effort_minutes, required, order_index,
      generated_by, generation_version
    ) values (
      v_preview.owner_id,
      v_preview.quest_id,
      v_current_mission_id,
      v_task->>'title',
      v_task->>'action',
      v_task->>'purpose',
      v_task->>'doneCondition',
      v_task->>'expectedOutput',
      greatest(1, least(1440, coalesce((v_task->>'estimatedEffortMinutes')::integer, 30))),
      coalesce((v_task->>'required')::boolean, true),
      v_task_count,
      'arc',
      'quest-hierarchy-3.1'
    ) returning id into v_task_id;
    v_task_ids := v_task_ids || jsonb_build_object(v_task->>'clientId', v_task_id);
    v_task_count := v_task_count + 1;
  end loop;

  for v_task in
    select value
    from jsonb_array_elements(v_preview.plan_payload #> '{currentTaskPlan,tasks}')
  loop
    for v_dependency in
      select value
      from jsonb_array_elements_text(coalesce(v_task->'dependencies', '[]'::jsonb))
    loop
      if v_task_ids ? v_dependency then
        insert into public.task_dependencies(task_id, depends_on_task_id)
        values(
          (v_task_ids->>(v_task->>'clientId'))::uuid,
          (v_task_ids->>v_dependency)::uuid
        ) on conflict do nothing;
      end if;
    end loop;
    update public.tasks
    set dependency_ids = coalesce((
      select array_agg((v_task_ids->>dependency)::uuid)
      from jsonb_array_elements_text(
        coalesce(v_task->'dependencies', '[]'::jsonb)
      ) dependency
      where v_task_ids ? dependency
    ), '{}'::uuid[])
    where id = (v_task_ids->>(v_task->>'clientId'))::uuid;
  end loop;

  update public.quests
  set
    active_route_id = v_route_id,
    hierarchy_version = 2,
    estimated_mission_count = v_count,
    updated_at = now()
  where id = v_preview.quest_id;

  update public.quest_plan_previews
  set status = 'approved', approved_at = now()
  where id = v_preview.id;

  update public.quest_planning_runs
  set status = 'approved', completed_at = now()
  where id = v_preview.planning_run_id;

  perform public.recalculate_quest_hierarchy_progress(v_preview.quest_id);

  return jsonb_build_object(
    'preview_id', v_preview.id,
    'status', 'approved',
    'route_id', v_route_id,
    'application_mode', v_application_mode,
    'carried_completed_count', v_carried_count,
    'replaced_mission_count', v_base_count - v_carried_count,
    'mission_count', v_count,
    'task_count', v_task_count,
    'mission_ids', v_ids,
    'task_ids', v_task_ids
  );
end;
$$;

revoke all on function public.approve_quest_plan_preview(uuid, uuid)
from public, anon;
grant execute on function public.approve_quest_plan_preview(uuid, uuid)
to authenticated;

comment on function public.approve_quest_plan_preview(uuid, uuid) is
  'Atomically preserves completed Missions and replaces only the reviewed unfinished route after an ownership and stale-snapshot check.';
