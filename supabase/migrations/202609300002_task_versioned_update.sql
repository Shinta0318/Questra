begin;

create table if not exists public.task_update_operations (
  owner_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  operation_id text not null,
  request_hash text not null,
  result_version integer not null,
  created_at timestamptz not null default now(),
  primary key (owner_id, task_id, operation_id),
  constraint task_update_operation_id_length check (length(operation_id) between 1 and 120)
);

alter table public.task_update_operations enable row level security;
revoke all on public.task_update_operations from anon, authenticated;

create or replace function public.update_task_if_version(
  p_task_id uuid,
  p_expected_version integer,
  p_operation_id text,
  p_payload jsonb
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
  if p_expected_version is null or p_expected_version < 1 then
    raise exception 'expected_version_required';
  end if;
  if p_operation_id is null or length(p_operation_id) not between 1 and 120 then
    raise exception 'operation_id_invalid';
  end if;
  if jsonb_typeof(p_payload) is distinct from 'object' then
    raise exception 'task_payload_invalid';
  end if;
  v_hash := md5((p_payload || jsonb_build_object('_expected_version', p_expected_version))::text);

  select * into v_task from public.tasks where id = p_task_id for update;
  if v_task.id is null or v_task.owner_id <> v_actor then
    raise exception 'task_not_owned';
  end if;
  select * into v_existing from public.task_update_operations
    where owner_id = v_actor and task_id = p_task_id and operation_id = p_operation_id;
  if v_existing.operation_id is not null then
    if v_existing.request_hash <> v_hash then
      raise exception 'operation_payload_mismatch';
    end if;
    return jsonb_build_object('status', 'already_applied', 'version', v_existing.result_version);
  end if;
  if v_task.version <> p_expected_version then
    return jsonb_build_object('status', 'conflict', 'version', v_task.version);
  end if;
  if p_payload->>'id' is distinct from p_task_id::text
     or p_payload->>'owner_id' is distinct from v_actor::text
     or p_payload->>'quest_id' is distinct from v_task.quest_id::text
     or p_payload->>'mission_id' is distinct from v_task.mission_id::text then
    raise exception 'task_parent_scope_mismatch';
  end if;
  if not exists (
    select 1 from public.missions m
    join public.quests q on q.id = m.quest_id
    where m.id = v_task.mission_id and m.quest_id = v_task.quest_id
      and q.owner_id = v_actor
  ) then
    raise exception 'task_parent_not_owned';
  end if;
  if (v_task.status = 'completed' and p_payload->>'status' is distinct from 'completed')
     or (v_task.status <> 'completed' and p_payload->>'status' = 'completed') then
    raise exception 'task_completion_requires_dedicated_rpc';
  end if;
  if exists (
    select 1 from jsonb_array_elements_text(coalesce(p_payload->'dependency_ids', '[]'::jsonb)) as dependency_id(value)
    left join public.tasks dependency on dependency.id = dependency_id.value::uuid
    where dependency.id is null or dependency.owner_id <> v_actor
      or dependency.mission_id <> v_task.mission_id
  ) then raise exception 'task_dependency_scope_mismatch'; end if;

  update public.tasks set
    title = p_payload->>'title',
    action = p_payload->>'action',
    purpose = coalesce(p_payload->>'purpose', ''),
    done_condition = p_payload->>'done_condition',
    expected_output = coalesce(p_payload->>'expected_output', ''),
    estimated_effort_minutes = (p_payload->>'estimated_effort_minutes')::integer,
    status = p_payload->>'status',
    required = (p_payload->>'required')::boolean,
    order_index = (p_payload->>'order_index')::integer,
    dependency_ids = array(select value::uuid from jsonb_array_elements_text(coalesce(p_payload->'dependency_ids', '[]'::jsonb)) as dependency_id(value)),
    scheduled_date = (p_payload->>'scheduled_date')::date,
    due_date = (p_payload->>'due_date')::date,
    verification_type = p_payload->>'verification_type',
    version = version + 1,
    updated_at = now()
  where id = p_task_id and owner_id = v_actor and version = p_expected_version
  returning * into v_task;
  if v_task.id is null then raise exception 'task_version_conflict'; end if;

  insert into public.task_update_operations
    (owner_id, task_id, operation_id, request_hash, result_version)
  values (v_actor, p_task_id, p_operation_id, v_hash, v_task.version);
  return jsonb_build_object('status', 'applied', 'version', v_task.version);
end;
$$;

revoke all on function public.update_task_if_version(uuid, integer, text, jsonb) from public, anon;
grant execute on function public.update_task_if_version(uuid, integer, text, jsonb) to authenticated;

commit;
