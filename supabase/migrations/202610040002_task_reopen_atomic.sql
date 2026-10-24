begin;

create or replace function public.reopen_task_journey(
  p_task_id uuid,
  p_operation_id text,
  p_expected_version integer
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_task public.tasks%rowtype;
  v_existing public.task_update_operations%rowtype;
  v_hash text;
begin
  if v_actor is null then raise exception 'authentication_required'; end if;
  if p_operation_id is null or length(p_operation_id) not between 1 and 120 then
    raise exception 'operation_id_invalid';
  end if;
  if p_expected_version is null or p_expected_version < 1 then
    raise exception 'expected_version_required';
  end if;
  v_hash := md5('reopen:' || p_task_id::text || ':' || p_expected_version::text);

  select * into v_task from public.tasks where id = p_task_id for update;
  if v_task.id is null or v_task.owner_id <> v_actor then
    raise exception 'task_not_owned';
  end if;
  if not exists (
    select 1 from public.missions m
    join public.quests q on q.id = m.quest_id
    where m.id = v_task.mission_id and m.quest_id = v_task.quest_id
      and q.owner_id = v_actor
  ) then
    raise exception 'task_parent_not_owned';
  end if;
  select * into v_existing from public.task_update_operations
  where owner_id = v_actor and task_id = p_task_id and operation_id = p_operation_id;
  if v_existing.operation_id is not null then
    if v_existing.request_hash <> v_hash then
      raise exception 'operation_payload_mismatch';
    end if;
    if v_task.version is distinct from v_existing.result_version
       or v_task.status is distinct from 'pending'
       or v_task.completed_at is not null then
      return jsonb_build_object('status', 'conflict', 'version', v_task.version);
    end if;
    return jsonb_build_object(
      'status', 'already_applied', 'task_id', v_task.id,
      'version', v_task.version, 'completed_at', null
    );
  end if;
  if v_task.version <> p_expected_version or v_task.status <> 'completed' then
    return jsonb_build_object('status', 'conflict', 'version', v_task.version);
  end if;
  perform 1 from public.tasks dependent
    where dependent.owner_id = v_actor
      and dependent.mission_id = v_task.mission_id
      and p_task_id = any(dependent.dependency_ids)
    for update;
  if exists (
    select 1 from public.tasks dependent
    where dependent.owner_id = v_actor
      and dependent.mission_id = v_task.mission_id
      and p_task_id = any(dependent.dependency_ids)
      and dependent.status in ('in_progress', 'completed')
  ) then
    return jsonb_build_object('status', 'conflict', 'version', v_task.version);
  end if;

  update public.tasks set
    status = 'pending', completed_at = null,
    version = version + 1, updated_at = now()
  where id = p_task_id and owner_id = v_actor and version = p_expected_version
  returning * into v_task;
  if v_task.id is null then raise exception 'task_version_conflict'; end if;

  if v_task.required then
    update public.missions set
      success_confirmed_at = null, completed_at = null,
      status = 'todo', updated_at = now()
    where id = v_task.mission_id and success_confirmed_at is not null;
    perform public.recalculate_quest_hierarchy_progress(v_task.quest_id);
  end if;

  insert into public.task_update_operations
    (owner_id, task_id, operation_id, request_hash, result_version)
  values (v_actor, p_task_id, p_operation_id, v_hash, v_task.version);
  return jsonb_build_object(
    'status', 'reopened', 'task_id', v_task.id,
    'version', v_task.version, 'completed_at', null
  );
end;
$$;

revoke all on function public.reopen_task_journey(uuid, text, integer) from public, anon;
grant execute on function public.reopen_task_journey(uuid, text, integer) to authenticated;

commit;
