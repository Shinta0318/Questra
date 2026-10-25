begin;

create table if not exists public.task_batch_operations (
  owner_id uuid not null references auth.users(id) on delete cascade,
  operation_id text not null,
  request_hash text not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (owner_id, operation_id),
  constraint task_batch_operation_id_length check (length(operation_id) between 1 and 120)
);

alter table public.task_batch_operations enable row level security;
revoke all on public.task_batch_operations from public, anon, authenticated;

create or replace function public.create_tasks_if_absent(
  p_operation_id text,
  p_tasks jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_hash text;
  v_previous public.task_batch_operations%rowtype;
  v_item jsonb;
  v_id uuid;
  v_quest uuid;
  v_mission uuid;
  v_locked_mission uuid;
  v_result jsonb;
begin
  if v_actor is null then raise exception 'authentication_required'; end if;
  if p_operation_id is null or length(p_operation_id) not between 1 and 120 then
    raise exception 'operation_id_invalid';
  end if;
  if jsonb_typeof(p_tasks) is distinct from 'array' then
    raise exception 'task_batch_payload_invalid';
  end if;
  if jsonb_array_length(p_tasks) not between 1 and 200 then
    raise exception 'task_batch_size_invalid';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_tasks) as payload(task_json)
    group by payload.task_json->>'id' having count(*) > 1
  ) then raise exception 'duplicate_task_ids'; end if;

  v_hash := md5(p_tasks::text);
  perform pg_advisory_xact_lock(
    hashtextextended(v_actor::text || ':' || p_operation_id, 0)
  );

  -- Serialize creates with reorders for each affected Mission.
  for v_mission in
    select distinct (payload.task_json->>'mission_id')::uuid
    from jsonb_array_elements(p_tasks) as payload(task_json)
    order by 1
  loop
    select m.id into v_locked_mission
    from public.missions m
    join public.quests q on q.id = m.quest_id
    where m.id = v_mission and q.owner_id = v_actor
    for update of m;
    if v_locked_mission is null then
      raise exception 'task_parent_scope_mismatch';
    end if;
  end loop;

  select * into v_previous from public.task_batch_operations
    where owner_id = v_actor and operation_id = p_operation_id;
  if v_previous.operation_id is not null then
    if v_previous.request_hash <> v_hash then
      raise exception 'operation_payload_mismatch';
    end if;
    if exists (
      select 1
      from jsonb_array_elements(p_tasks) as payload(task_json)
      left join public.tasks task
        on task.id = (payload.task_json->>'id')::uuid
       and task.owner_id = v_actor
      where task.id is null
         or task.quest_id::text is distinct from payload.task_json->>'quest_id'
         or task.mission_id::text is distinct from payload.task_json->>'mission_id'
         or task.version is distinct from 1
         or task.status is distinct from payload.task_json->>'status'
         or task.order_index is distinct from
            (payload.task_json->>'order_index')::integer
    ) then
      return jsonb_build_object('status', 'conflict');
    end if;
    return v_previous.result || jsonb_build_object('status', 'already_applied');
  end if;

  for v_item in
    select payload.task_json
    from jsonb_array_elements(p_tasks) as payload(task_json)
    order by payload.task_json->>'id'
  loop
    if jsonb_typeof(v_item) is distinct from 'object' then
      raise exception 'task_row_invalid';
    end if;
    v_id := (v_item->>'id')::uuid;
    v_quest := (v_item->>'quest_id')::uuid;
    v_mission := (v_item->>'mission_id')::uuid;
    if v_id is null or v_quest is null or v_mission is null
       or v_item->>'owner_id' is distinct from v_actor::text
       or not exists (
         select 1 from public.missions m
         join public.quests q on q.id = m.quest_id
         where m.id = v_mission and m.quest_id = v_quest and q.owner_id = v_actor
       ) then raise exception 'task_parent_scope_mismatch'; end if;
    if (v_item->>'version')::integer is distinct from 1
       or v_item->>'status' = 'completed' then
      raise exception 'new_task_state_invalid';
    end if;
    if exists (select 1 from public.tasks where id = v_id) then
      return jsonb_build_object('status', 'conflict');
    end if;
  end loop;

  for v_item in
    select payload.task_json
    from jsonb_array_elements(p_tasks) as payload(task_json)
    order by payload.task_json->>'id'
  loop
    insert into public.tasks (
      id, owner_id, quest_id, mission_id, title, action, purpose,
      done_condition, expected_output, estimated_effort_minutes,
      status, required, order_index, dependency_ids, scheduled_date,
      due_date, completed_at, verification_type, generated_by, origin,
      version, generation_version
    ) values (
      (v_item->>'id')::uuid, v_actor, (v_item->>'quest_id')::uuid,
      (v_item->>'mission_id')::uuid, v_item->>'title', v_item->>'action',
      coalesce(v_item->>'purpose', ''), v_item->>'done_condition',
      coalesce(v_item->>'expected_output', ''),
      (v_item->>'estimated_effort_minutes')::integer,
      v_item->>'status', (v_item->>'required')::boolean,
      (v_item->>'order_index')::integer, '{}'::uuid[],
      (v_item->>'scheduled_date')::date, (v_item->>'due_date')::date,
      null, v_item->>'verification_type', v_item->>'generated_by',
      v_item->>'origin', 1, v_item->>'generation_version'
    );
  end loop;

  for v_item in
    select payload.task_json
    from jsonb_array_elements(p_tasks) as payload(task_json)
  loop
    update public.tasks set dependency_ids = array(
      select dependency.value::uuid from jsonb_array_elements_text(
        coalesce(v_item->'dependency_ids', '[]'::jsonb)
      ) as dependency(value)
    ) where id = (v_item->>'id')::uuid and owner_id = v_actor;
  end loop;

  v_result := jsonb_build_object(
    'status', 'applied', 'count', jsonb_array_length(p_tasks)
  );
  insert into public.task_batch_operations
    (owner_id, operation_id, request_hash, result)
  values (v_actor, p_operation_id, v_hash, v_result);
  return v_result;
end;
$$;

drop function if exists public.reorder_mission_tasks(uuid, uuid[], text);
create function public.reorder_mission_tasks(
  p_mission_id uuid,
  p_task_ids uuid[],
  p_operation_id text,
  p_expected_versions jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_hash text;
  v_previous public.task_batch_operations%rowtype;
  v_task public.tasks%rowtype;
  v_locked_mission uuid;
  v_count integer := 0;
  v_expected_count integer;
  v_result jsonb;
begin
  if v_actor is null then raise exception 'authentication_required'; end if;
  if p_operation_id is null or length(p_operation_id) not between 1 and 120 then
    raise exception 'operation_id_invalid';
  end if;
  if coalesce(array_length(p_task_ids, 1), 0) = 0
     or array_length(p_task_ids, 1) > 200
     or jsonb_typeof(p_expected_versions) is distinct from 'object' then
    raise exception 'task_reorder_payload_invalid';
  end if;
  if array_length(p_task_ids, 1) <>
     (select count(distinct task_id) from unnest(p_task_ids) as ids(task_id)) then
    raise exception 'duplicate_task_ids';
  end if;
  select count(*) into v_expected_count from jsonb_each(p_expected_versions);
  if v_expected_count <> array_length(p_task_ids, 1) then
    raise exception 'task_reorder_expected_versions_invalid';
  end if;

  v_hash := md5(jsonb_build_object(
    'missionId', p_mission_id, 'taskIds', to_jsonb(p_task_ids),
    'expectedVersions', p_expected_versions
  )::text);
  perform pg_advisory_xact_lock(
    hashtextextended(v_actor::text || ':' || p_operation_id, 0)
  );
  select m.id into v_locked_mission
  from public.missions m
  join public.quests q on q.id = m.quest_id
  where m.id = p_mission_id and q.owner_id = v_actor
  for update of m;
  if v_locked_mission is null then
    return jsonb_build_object('status', 'conflict');
  end if;
  if (select count(*) from public.tasks where mission_id = p_mission_id)
     <> array_length(p_task_ids, 1) then
    return jsonb_build_object('status', 'conflict');
  end if;
  select * into v_previous from public.task_batch_operations
    where owner_id = v_actor and operation_id = p_operation_id;
  if v_previous.operation_id is not null then
    if v_previous.request_hash <> v_hash then
      raise exception 'operation_payload_mismatch';
    end if;
    if exists (
      select 1
      from unnest(p_task_ids) with ordinality as ordered(id, position)
      left join public.tasks task on task.id = ordered.id
      where task.id is null or task.owner_id <> v_actor
        or task.mission_id <> p_mission_id
        or task.version is distinct from
          (p_expected_versions->>(ordered.id::text))::integer + 1
        or task.order_index is distinct from ordered.position - 1
    ) then
      return jsonb_build_object('status', 'conflict');
    end if;
    return v_previous.result || jsonb_build_object('status', 'already_applied');
  end if;
  for v_task in
    select * from public.tasks where id = any(p_task_ids) order by id for update
  loop
    if v_task.owner_id <> v_actor or v_task.mission_id <> p_mission_id
       or p_expected_versions->>(v_task.id::text) is distinct from v_task.version::text then
      return jsonb_build_object('status', 'conflict');
    end if;
    v_count := v_count + 1;
  end loop;
  if v_count <> array_length(p_task_ids, 1) then
    return jsonb_build_object('status', 'conflict');
  end if;

  update public.tasks task
  set order_index = ordered.position - 1,
      version = task.version + 1,
      updated_at = now()
  from unnest(p_task_ids) with ordinality ordered(id, position)
  where task.id = ordered.id and task.owner_id = v_actor
    and task.mission_id = p_mission_id;

  v_result := jsonb_build_object(
    'status', 'applied', 'updated_count', v_count
  );
  insert into public.task_batch_operations
    (owner_id, operation_id, request_hash, result)
  values (v_actor, p_operation_id, v_hash, v_result);
  return v_result;
end;
$$;

revoke all on function public.create_tasks_if_absent(text, jsonb) from public, anon;
revoke all on function public.reorder_mission_tasks(uuid, uuid[], text, jsonb) from public, anon;
grant execute on function public.create_tasks_if_absent(text, jsonb) to authenticated;
grant execute on function public.reorder_mission_tasks(uuid, uuid[], text, jsonb) to authenticated;
revoke insert, update, delete on public.tasks from authenticated;

commit;
