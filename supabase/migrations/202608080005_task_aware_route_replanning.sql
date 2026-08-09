-- QST-279: transactional Task-aware route proposals and rollback.
begin;

alter table public.route_change_items
  add column if not exists target_task_id uuid references public.tasks(id) on delete set null;
alter table public.route_change_proposals
  add column if not exists created_task_ids uuid[] not null default '{}'::uuid[];

create index if not exists route_change_items_target_task_idx
  on public.route_change_items(target_task_id) where target_task_id is not null;

create or replace function public.apply_task_aware_route_change_proposal(
  p_proposal_id uuid,
  p_accepted_item_ids uuid[],
  p_expected_route_version_id uuid
) returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := auth.uid();
  v_proposal public.route_change_proposals%rowtype;
  v_version public.route_versions%rowtype;
  v_item public.route_change_items%rowtype;
  v_task public.tasks%rowtype;
  v_value jsonb;
  v_created uuid;
  v_previous_created uuid;
  v_created_ids uuid[] := '{}'::uuid[];
  v_accepted uuid[];
  v_status text;
begin
  if v_actor is null then raise exception 'authentication_required'; end if;
  select * into v_proposal from public.route_change_proposals
    where id = p_proposal_id for update;
  if not found or not exists (
    select 1 from public.quests where id = v_proposal.quest_id and owner_id = v_actor
  ) then raise exception 'proposal_not_found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_proposal.quest_id::text, 0));
  if v_proposal.status <> 'pending' then raise exception 'proposal_not_pending'; end if;
  if v_proposal.route_version_id <> p_expected_route_version_id then raise exception 'stale_route_version'; end if;
  select * into v_version from public.route_versions
    where id = v_proposal.route_version_id and quest_id = v_proposal.quest_id for update;
  if not found then raise exception 'route_version_not_found'; end if;

  select coalesce(array_agg(distinct item_id), '{}'::uuid[]) into v_accepted
  from unnest(coalesce(p_accepted_item_ids, '{}'::uuid[])) item_id;
  if cardinality(v_accepted) = 0 then raise exception 'no_route_changes_selected'; end if;
  if (select count(*) from public.route_change_items
      where proposal_id = p_proposal_id and id = any(v_accepted)) <> cardinality(v_accepted)
  then raise exception 'invalid_route_change_selection'; end if;

  update public.route_versions set route_snapshot =
    coalesce(route_snapshot, '{}'::jsonb) || jsonb_build_object('tasks', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id,
        'missionId', t.mission_id,
        'status', t.status,
        'orderIndex', t.order_index,
        'dependencyIds', to_jsonb(t.dependency_ids),
        'scheduledDate', t.scheduled_date,
        'dueDate', t.due_date
      ) order by t.mission_id, t.order_index)
      from public.tasks t where t.quest_id = v_proposal.quest_id
    ), '[]'::jsonb))
  where id = v_proposal.route_version_id;

  for v_item in select * from public.route_change_items
    where proposal_id = p_proposal_id and id = any(v_accepted) order by id
  loop
    if v_item.target_task_id is not null then
      select * into v_task from public.tasks
      where id = v_item.target_task_id and quest_id = v_proposal.quest_id
      for update;
      if not found then raise exception 'task_not_found'; end if;
      if v_task.status = 'completed' then raise exception 'completed_task_is_immutable'; end if;

      if v_item.action_type = 'split' then
        if jsonb_typeof(v_item.after_data->'tasks') <> 'array' then
          raise exception 'task_split_payload_invalid';
        end if;
        update public.tasks set status = 'cancelled', updated_at = now()
          where id = v_task.id and status <> 'completed';
        v_previous_created := null;
        for v_value in select value from jsonb_array_elements(v_item.after_data->'tasks') loop
          insert into public.tasks(
            owner_id, quest_id, mission_id, title, action, purpose,
            done_condition, expected_output, estimated_effort_minutes,
            status, required, order_index, dependency_ids,
            generated_by, generation_version
          ) values (
            v_task.owner_id, v_task.quest_id, v_task.mission_id,
            v_value->>'title', v_value->>'action', v_task.purpose,
            v_value->>'doneCondition', v_task.expected_output,
            nullif(v_value->>'estimatedEffortMinutes','')::integer,
            'pending', v_task.required,
            v_task.order_index + cardinality(v_created_ids),
            case when v_previous_created is null then v_task.dependency_ids else array[v_previous_created] end,
            'arc', 'qst-279-v1'
          ) returning id into v_created;
          v_created_ids := array_append(v_created_ids, v_created);
          v_previous_created := v_created;
        end loop;
      elsif v_item.action_type = 'reorder' then
        update public.tasks set
          order_index = greatest(0, coalesce((v_item.after_data->>'orderIndex')::integer, order_index)),
          updated_at = now()
        where id = v_task.id and status <> 'completed';
      elsif v_item.action_type = 'reschedule' then
        update public.tasks set
          scheduled_date = nullif(v_item.after_data->>'scheduledDate','')::timestamptz::date,
          due_date = coalesce(nullif(v_item.after_data->>'dueDate','')::timestamptz::date, due_date),
          updated_at = now()
        where id = v_task.id and status <> 'completed';
      else
        raise exception 'unsupported_task_route_action:%', v_item.action_type;
      end if;
    elsif v_item.action_type = 'add' and v_item.target_mission_id is not null then
      v_value := v_item.after_data->'task';
      if jsonb_typeof(v_value) <> 'object' then raise exception 'task_add_payload_invalid'; end if;
      insert into public.tasks(
        owner_id, quest_id, mission_id, title, action, purpose,
        done_condition, estimated_effort_minutes, status, required,
        order_index, generated_by, generation_version
      ) select
        v_actor, v_proposal.quest_id, m.id,
        v_value->>'title', v_value->>'action', coalesce(v_value->>'purpose', m.objective),
        v_value->>'doneCondition', nullif(v_value->>'estimatedEffortMinutes','')::integer,
        'pending', coalesce((v_value->>'required')::boolean, true),
        coalesce((v_value->>'orderIndex')::integer, 0), 'arc', 'qst-279-v1'
      from public.missions m
      where m.id = v_item.target_mission_id
        and m.quest_id = v_proposal.quest_id
        and m.status <> 'completed'
      returning id into v_created;
      if v_created is null then raise exception 'mission_not_available_for_task'; end if;
      v_created_ids := array_append(v_created_ids, v_created);
    elsif v_item.action_type = 'reschedule' then
      update public.quests set
        target_date = nullif(v_item.after_data->>'targetDate','')::timestamptz,
        updated_at = now()
      where id = v_proposal.quest_id;
    else
      raise exception 'unsupported_task_aware_route_action:%', v_item.action_type;
    end if;
  end loop;

  v_status := case when cardinality(v_accepted) = (
    select count(*) from public.route_change_items where proposal_id = p_proposal_id
  ) then 'accepted' else 'partiallyAccepted' end;
  update public.route_versions set status='active', approved_at=now(), approved_by=v_actor
    where id=v_proposal.route_version_id;
  update public.route_versions set status='superseded'
    where quest_id=v_proposal.quest_id and id<>v_proposal.route_version_id and status='active';
  update public.route_change_proposals set
    status=v_status, accepted_item_ids=v_accepted, created_task_ids=v_created_ids,
    resolved_at=now(), applied_at=now()
  where id=p_proposal_id;
  perform public.recalculate_quest_hierarchy_progress(v_proposal.quest_id);
  return jsonb_build_object(
    'proposal_id',p_proposal_id,'quest_id',v_proposal.quest_id,
    'route_version_id',v_proposal.route_version_id,'status',v_status
  );
end;
$$;

create or replace function public.rollback_task_aware_route_change_proposal(p_proposal_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := auth.uid();
  v_proposal public.route_change_proposals%rowtype;
  v_version public.route_versions%rowtype;
  v_snapshot jsonb;
begin
  if v_actor is null then raise exception 'authentication_required'; end if;
  select * into v_proposal from public.route_change_proposals
    where id=p_proposal_id for update;
  if not found or not exists(
    select 1 from public.quests where id=v_proposal.quest_id and owner_id=v_actor
  ) then raise exception 'proposal_not_found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_proposal.quest_id::text, 0));
  if v_proposal.status not in ('accepted','partiallyAccepted') then
    raise exception 'proposal_not_rollbackable';
  end if;
  select * into v_version from public.route_versions
    where id=v_proposal.route_version_id for update;
  v_snapshot := v_version.route_snapshot->'tasks';
  if jsonb_typeof(v_snapshot) <> 'array' then raise exception 'task_snapshot_unavailable'; end if;

  delete from public.tasks where id=any(v_proposal.created_task_ids) and status <> 'completed';
  update public.tasks t set
    status = s.status,
    order_index = s."orderIndex",
    dependency_ids = s."dependencyIds",
    scheduled_date = s."scheduledDate",
    due_date = s."dueDate",
    updated_at = now()
  from jsonb_to_recordset(v_snapshot) as s(
    id uuid, "missionId" uuid, status text, "orderIndex" integer,
    "dependencyIds" uuid[], "scheduledDate" date, "dueDate" date
  )
  where t.id=s.id and t.quest_id=v_proposal.quest_id
    and not (t.status='completed' and s.status <> 'completed');

  update public.route_change_proposals set status='rolledBack', rolled_back_at=now()
    where id=p_proposal_id;
  update public.route_versions set status='rolled_back' where id=v_proposal.route_version_id;
  update public.route_versions set status='active'
    where id=(select id from public.route_versions
      where quest_id=v_proposal.quest_id and status='superseded'
      order by version_number desc limit 1);
  perform public.recalculate_quest_hierarchy_progress(v_proposal.quest_id);
  return jsonb_build_object(
    'proposal_id',p_proposal_id,'quest_id',v_proposal.quest_id,
    'route_version_id',v_proposal.route_version_id,'status','rolledBack'
  );
end;
$$;

revoke all on function public.apply_task_aware_route_change_proposal(uuid,uuid[],uuid),
  public.rollback_task_aware_route_change_proposal(uuid) from public, anon;
grant execute on function public.apply_task_aware_route_change_proposal(uuid,uuid[],uuid),
  public.rollback_task_aware_route_change_proposal(uuid) to authenticated;

commit;
