create or replace function public.apply_mission_regeneration_proposal(
  p_proposal_id uuid,
  p_item_id uuid,
  p_expected_route_version_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor_id uuid := auth.uid();
  proposal_record public.route_change_proposals%rowtype;
  item_record public.route_change_items%rowtype;
  resolved_status text;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  select * into proposal_record from public.route_change_proposals
    where id = p_proposal_id for update;
  if not found or not exists (
    select 1 from public.quests
    where id = proposal_record.quest_id and owner_id = actor_id
  ) then raise exception 'Proposal not found'; end if;
  if proposal_record.status <> 'pending' then
    raise exception 'Proposal is no longer pending';
  end if;
  if proposal_record.route_version_id <> p_expected_route_version_id then
    raise exception 'Stale route version';
  end if;

  select * into item_record from public.route_change_items
    where id = p_item_id
      and proposal_id = p_proposal_id
      and action_type = 'replace'
    for update;
  if not found or item_record.target_mission_id is null then
    raise exception 'Replacement item not found';
  end if;
  if char_length(trim(coalesce(item_record.after_data->>'title', ''))) not between 1 and 160 then
    raise exception 'Invalid Mission title';
  end if;

  update public.missions set
    title = trim(item_record.after_data->>'title'),
    description = coalesce(item_record.after_data->>'description', description),
    done_condition = coalesce(item_record.after_data->>'doneCondition', done_condition),
    expected_output = coalesce(item_record.after_data->>'expectedOutput', expected_output),
    estimated_duration_days = coalesce(
      nullif(item_record.after_data->>'estimatedDurationDays', '')::integer,
      estimated_duration_days
    ),
    difficulty_score = coalesce(
      nullif(item_record.after_data->>'difficultyScore', '')::integer,
      difficulty_score
    ),
    source_requirement = coalesce(
      nullif(item_record.after_data->>'sourceRequirement', ''),
      source_requirement
    ),
    confidence = coalesce(
      nullif(item_record.after_data->>'confidence', '')::double precision,
      confidence
    ),
    updated_at = now()
  where id = item_record.target_mission_id
    and quest_id = proposal_record.quest_id
    and status <> 'completed';
  if not found then raise exception 'Mission cannot be replaced'; end if;

  resolved_status := case
    when (select count(*) from public.route_change_items where proposal_id = p_proposal_id) = 1
      then 'accepted'
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
    accepted_item_ids = array[p_item_id],
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

create or replace function public.rollback_route_change_proposal_v2(
  p_proposal_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor_id uuid := auth.uid();
  proposal_record public.route_change_proposals%rowtype;
  item_record public.route_change_items%rowtype;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  select * into proposal_record from public.route_change_proposals
    where id = p_proposal_id for update;
  if not found or not exists (
    select 1 from public.quests
    where id = proposal_record.quest_id and owner_id = actor_id
  ) then raise exception 'Proposal not found'; end if;

  select * into item_record from public.route_change_items
    where proposal_id = p_proposal_id
      and action_type = 'replace'
      and id = any(proposal_record.accepted_item_ids)
    limit 1;
  if not found then
    return public.rollback_route_change_proposal(p_proposal_id);
  end if;
  if proposal_record.status not in ('accepted', 'partiallyAccepted') then
    raise exception 'Proposal cannot be rolled back';
  end if;

  update public.missions set
    title = coalesce(item_record.before_data->>'title', title),
    description = coalesce(item_record.before_data->>'description', description),
    done_condition = coalesce(item_record.before_data->>'doneCondition', done_condition),
    expected_output = coalesce(item_record.before_data->>'expectedOutput', expected_output),
    estimated_duration_days = nullif(item_record.before_data->>'estimatedDurationDays', '')::integer,
    difficulty_score = nullif(item_record.before_data->>'difficultyScore', '')::integer,
    source_requirement = coalesce(
      nullif(item_record.before_data->>'sourceRequirement', ''),
      source_requirement
    ),
    confidence = coalesce(
      nullif(item_record.before_data->>'confidence', '')::double precision,
      confidence
    ),
    updated_at = now()
  where id = item_record.target_mission_id
    and quest_id = proposal_record.quest_id;

  update public.route_versions set status = 'rolled_back'
    where id = proposal_record.route_version_id;
  update public.route_change_proposals set
    status = 'rolledBack', rolled_back_at = now()
    where id = p_proposal_id;
  return jsonb_build_object(
    'proposal_id', p_proposal_id,
    'quest_id', proposal_record.quest_id,
    'route_version_id', proposal_record.route_version_id,
    'status', 'rolledBack'
  );
end;
$$;

revoke all on function public.apply_mission_regeneration_proposal(uuid, uuid, uuid) from public;
grant execute on function public.apply_mission_regeneration_proposal(uuid, uuid, uuid) to authenticated;
revoke all on function public.rollback_route_change_proposal_v2(uuid) from public;
grant execute on function public.rollback_route_change_proposal_v2(uuid) to authenticated;
