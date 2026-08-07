begin;

alter table public.route_change_proposals
  add column if not exists applied_at timestamptz,
  add column if not exists rolled_back_at timestamptz,
  add column if not exists created_mission_ids uuid[] not null default '{}'::uuid[];

create or replace function public.apply_route_change_proposal(
  p_proposal_id uuid,
  p_accepted_item_ids uuid[],
  p_expected_route_version_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor_id uuid := auth.uid();
  proposal_record public.route_change_proposals%rowtype;
  version_record public.route_versions%rowtype;
  item_record public.route_change_items%rowtype;
  source_mission public.missions%rowtype;
  split_value jsonb;
  snapshot jsonb;
  accepted_ids uuid[];
  created_ids uuid[] := '{}'::uuid[];
  created_id uuid;
  resolved_status text;
begin
  if actor_id is null then raise exception 'authentication required'; end if;

  select * into proposal_record from public.route_change_proposals
    where id = p_proposal_id for update;
  if not found then raise exception 'Proposal not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(proposal_record.quest_id::text, 0));

  if not exists (
    select 1 from public.quests
    where id = proposal_record.quest_id and owner_id = actor_id
  ) then raise exception 'Proposal not found'; end if;
  if proposal_record.status <> 'pending' then raise exception 'Proposal is no longer pending'; end if;
  if proposal_record.route_version_id <> p_expected_route_version_id then raise exception 'Stale route version'; end if;

  select * into version_record from public.route_versions
    where id = proposal_record.route_version_id and quest_id = proposal_record.quest_id
    for update;
  if not found then raise exception 'Route version not found'; end if;
  if exists (
    select 1 from public.route_versions
    where quest_id = proposal_record.quest_id
      and version_number > version_record.version_number
      and status in ('active', 'rolled_back')
  ) then raise exception 'A newer route version already exists'; end if;

  select coalesce(array_agg(distinct item_id), '{}'::uuid[]) into accepted_ids
    from unnest(coalesce(p_accepted_item_ids, '{}'::uuid[])) item_id;
  if cardinality(accepted_ids) = 0 then raise exception 'No route changes selected'; end if;
  if (
    select count(*) from public.route_change_items
    where proposal_id = p_proposal_id and id = any(accepted_ids)
  ) <> cardinality(accepted_ids) then raise exception 'Invalid route change selection'; end if;

  select jsonb_build_object(
    'quest', jsonb_build_object(
      'id', quest.id,
      'targetDate', quest.target_date,
      'requestedTargetMonth', quest.requested_target_month
    ),
    'missions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', mission.id,
        'sortOrder', mission.sort_order,
        'isToday', mission.is_today,
        'routeState', mission.route_state
      ) order by mission.sort_order)
      from public.missions mission where mission.quest_id = quest.id
    ), '[]'::jsonb)
  ) into snapshot
  from public.quests quest where quest.id = proposal_record.quest_id;

  update public.route_versions set route_snapshot = snapshot
    where id = proposal_record.route_version_id;

  for item_record in
    select * from public.route_change_items
    where proposal_id = p_proposal_id and id = any(accepted_ids)
    order by id
  loop
    if item_record.action_type = 'reschedule' then
      if nullif(item_record.after_data->>'targetDate', '') is null then
        raise exception 'Invalid target date';
      end if;
      update public.quests set
        target_date = (item_record.after_data->>'targetDate')::timestamptz::date,
        requested_target_month = date_trunc('month', (item_record.after_data->>'targetDate')::timestamptz)::date,
        updated_at = now()
      where id = proposal_record.quest_id;
    elsif item_record.action_type = 'reorder' then
      if item_record.target_mission_id is null then raise exception 'Mission is required'; end if;
      if not exists (
        select 1 from public.missions
        where id = item_record.target_mission_id and quest_id = proposal_record.quest_id
      ) then raise exception 'Mission not found'; end if;
      update public.missions set is_today = (id = item_record.target_mission_id), updated_at = now()
        where quest_id = proposal_record.quest_id;
    elsif item_record.action_type = 'split' then
      select * into source_mission from public.missions
        where id = item_record.target_mission_id
          and quest_id = proposal_record.quest_id
          and status <> 'completed'
        for update;
      if not found then raise exception 'Mission cannot be split'; end if;
      if coalesce(jsonb_typeof(item_record.after_data->'missions'), '') <> 'array'
        or coalesce(jsonb_array_length(item_record.after_data->'missions'), 0) not between 1 and 20
      then raise exception 'Invalid split Missions'; end if;

      update public.missions set route_state = 'removed', updated_at = now()
        where id = source_mission.id;
      for split_value in select * from jsonb_array_elements(item_record.after_data->'missions')
      loop
        if char_length(trim(split_value->>'title')) not between 1 and 160 then
          raise exception 'Invalid split Mission title';
        end if;
        created_id := gen_random_uuid();
        insert into public.missions (
          id, quest_id, title, description, guide_type, difficulty, status,
          progress_percent, sort_order, is_today, parent_mission_id,
          dependency_ids, priority, category, estimated_cost_label,
          reference_hints, enterprise_support_hints, difficulty_score,
          estimated_duration_days, route_state
        ) values (
          created_id, source_mission.quest_id, trim(split_value->>'title'),
          source_mission.description, source_mission.guide_type,
          source_mission.difficulty, 'todo', 0,
          source_mission.sort_order + cardinality(created_ids), false,
          source_mission.id, '{}'::uuid[], source_mission.priority,
          source_mission.category, source_mission.estimated_cost_label,
          source_mission.reference_hints, source_mission.enterprise_support_hints,
          source_mission.difficulty_score,
          nullif(split_value->>'estimatedDays', '')::integer, 'active'
        );
        created_ids := array_append(created_ids, created_id);
      end loop;
    elsif item_record.action_type in ('pause', 'remove', 'resume') then
      if item_record.target_mission_id is null then raise exception 'Mission is required'; end if;
      update public.missions set
        route_state = case item_record.action_type
          when 'pause' then 'paused'
          when 'remove' then 'removed'
          else 'active'
        end,
        updated_at = now()
      where id = item_record.target_mission_id
        and quest_id = proposal_record.quest_id
        and (item_record.action_type = 'resume' or status <> 'completed');
      if not found then raise exception 'Mission cannot be changed'; end if;
    else
      raise exception 'Unsupported route action: %', item_record.action_type;
    end if;
  end loop;

  resolved_status := case
    when cardinality(accepted_ids) = (
      select count(*) from public.route_change_items where proposal_id = p_proposal_id
    ) then 'accepted'
    else 'partiallyAccepted'
  end;

  update public.route_versions set
    status = 'active', approved_at = now(), approved_by = actor_id
    where id = proposal_record.route_version_id;
  update public.route_versions set status = 'superseded'
    where quest_id = proposal_record.quest_id
      and id <> proposal_record.route_version_id
      and status = 'active';
  update public.route_change_proposals set
    status = resolved_status,
    accepted_item_ids = accepted_ids,
    created_mission_ids = created_ids,
    resolved_at = now(),
    applied_at = now()
    where id = p_proposal_id;

  return jsonb_build_object(
    'proposal_id', p_proposal_id,
    'quest_id', proposal_record.quest_id,
    'route_version_id', proposal_record.route_version_id,
    'status', resolved_status
  );
end;
$$;

create or replace function public.rollback_route_change_proposal(
  p_proposal_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor_id uuid := auth.uid();
  proposal_record public.route_change_proposals%rowtype;
  version_record public.route_versions%rowtype;
  snapshot jsonb;
  mission_snapshot jsonb;
  rollback_version_id uuid := gen_random_uuid();
  rollback_version_number integer;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  select * into proposal_record from public.route_change_proposals
    where id = p_proposal_id for update;
  if not found then raise exception 'Proposal not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(proposal_record.quest_id::text, 0));

  if not exists (
    select 1 from public.quests
    where id = proposal_record.quest_id and owner_id = actor_id
  ) then raise exception 'Proposal not found'; end if;
  if proposal_record.status not in ('accepted', 'partiallyAccepted') then
    raise exception 'Proposal cannot be rolled back';
  end if;

  select * into version_record from public.route_versions
    where id = proposal_record.route_version_id for update;
  snapshot := version_record.route_snapshot;
  if snapshot is null or jsonb_typeof(snapshot->'missions') <> 'array' then
    raise exception 'Rollback snapshot is unavailable';
  end if;
  if exists (
    select 1 from public.route_versions
    where quest_id = proposal_record.quest_id
      and version_number > version_record.version_number
      and status = 'active'
  ) then raise exception 'A newer active route must be reviewed first'; end if;

  update public.quests set
    target_date = nullif(snapshot->'quest'->>'targetDate', '')::date,
    requested_target_month = nullif(snapshot->'quest'->>'requestedTargetMonth', '')::date,
    updated_at = now()
  where id = proposal_record.quest_id;

  for mission_snapshot in select * from jsonb_array_elements(snapshot->'missions')
  loop
    update public.missions set
      sort_order = (mission_snapshot->>'sortOrder')::integer,
      is_today = (mission_snapshot->>'isToday')::boolean,
      route_state = mission_snapshot->>'routeState',
      updated_at = now()
    where id = (mission_snapshot->>'id')::uuid
      and quest_id = proposal_record.quest_id;
  end loop;

  update public.missions set route_state = 'removed', is_today = false, updated_at = now()
    where id = any(proposal_record.created_mission_ids)
      and quest_id = proposal_record.quest_id;

  select coalesce(max(version_number), 0) + 1 into rollback_version_number
    from public.route_versions where quest_id = proposal_record.quest_id;
  update public.route_versions set status = 'rolled_back'
    where id = proposal_record.route_version_id;
  insert into public.route_versions (
    id, quest_id, version_number, status, generated_by, generation_reason,
    route_snapshot, approved_at, approved_by
  ) values (
    rollback_version_id, proposal_record.quest_id, rollback_version_number,
    'active', 'user', 'rollback:' || p_proposal_id::text, snapshot, now(), actor_id
  );
  update public.route_change_proposals set
    status = 'rolledBack', rolled_back_at = now(), resolved_at = now()
    where id = p_proposal_id;

  return jsonb_build_object(
    'proposal_id', p_proposal_id,
    'quest_id', proposal_record.quest_id,
    'route_version_id', rollback_version_id,
    'status', 'rolledBack'
  );
end;
$$;

revoke all on function public.apply_route_change_proposal(uuid, uuid[], uuid) from public;
revoke all on function public.rollback_route_change_proposal(uuid) from public;
grant execute on function public.apply_route_change_proposal(uuid, uuid[], uuid) to authenticated;
grant execute on function public.rollback_route_change_proposal(uuid) to authenticated;

comment on function public.apply_route_change_proposal(uuid, uuid[], uuid) is
  'Atomically validates and applies an owner-approved Route proposal.';
comment on function public.rollback_route_change_proposal(uuid) is
  'Restores persisted Route fields without deleting Mission or Trail history.';

commit;
