-- QST-286: prevent route proposals from overwriting progress changed after creation.
begin;

alter table public.route_change_proposals
  add column if not exists base_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists conflict_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists stale_reason text,
  add column if not exists stale_at timestamptz;

alter table public.route_change_proposals
  drop constraint if exists route_change_proposals_status_check;
alter table public.route_change_proposals
  add constraint route_change_proposals_status_check check (
    status in (
      'pending', 'accepted', 'partiallyAccepted', 'rejected', 'expired',
      'rolledBack', 'stale'
    )
  );

create or replace function public.capture_route_state(p_quest_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'snapshotVersion', 1,
    'quest', jsonb_build_object(
      'id', q.id,
      'targetDate', to_char(q.target_date at time zone 'UTC', 'YYYY-MM-DD')
    ),
    'missions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id,
        'status', m.status,
        'progressPercent', m.progress_percent,
        'sortOrder', m.sort_order,
        'isToday', m.is_today,
        'routeState', m.route_state
      ) order by m.id)
      from public.missions m where m.quest_id = q.id
    ), '[]'::jsonb),
    'tasks', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id,
        'missionId', t.mission_id,
        'status', t.status,
        'orderIndex', t.order_index,
        'dependencyIds', to_jsonb(t.dependency_ids),
        'scheduledDate', to_char(t.scheduled_date, 'YYYY-MM-DD'),
        'dueDate', to_char(t.due_date, 'YYYY-MM-DD')
      ) order by t.id)
      from public.tasks t where t.quest_id = q.id
    ), '[]'::jsonb)
  )
  from public.quests q where q.id = p_quest_id;
$$;

create or replace function public.capture_route_proposal_base()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.base_snapshot := public.capture_route_state(new.quest_id);
  new.conflict_snapshot := '{}'::jsonb;
  new.stale_reason := null;
  new.stale_at := null;
  return new;
end;
$$;

drop trigger if exists route_proposal_capture_base on public.route_change_proposals;
create trigger route_proposal_capture_base
before insert on public.route_change_proposals
for each row execute function public.capture_route_proposal_base();

update public.route_change_proposals p
set base_snapshot = public.capture_route_state(p.quest_id)
where p.status = 'pending' and p.base_snapshot = '{}'::jsonb;

create or replace function public.prepare_route_proposal_apply(p_proposal_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_proposal public.route_change_proposals%rowtype;
  v_current jsonb;
begin
  if v_actor is null then raise exception 'authentication_required'; end if;
  select * into v_proposal from public.route_change_proposals
    where id = p_proposal_id for update;
  if not found or not exists (
    select 1 from public.quests
    where id = v_proposal.quest_id and owner_id = v_actor
  ) then raise exception 'proposal_not_found'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_proposal.quest_id::text, 0));
  perform 1 from public.quests where id = v_proposal.quest_id for update;
  perform 1 from public.missions where quest_id = v_proposal.quest_id for update;
  perform 1 from public.tasks where quest_id = v_proposal.quest_id for update;

  if v_proposal.status <> 'pending' then
    return jsonb_build_object(
      'fresh', false,
      'status', v_proposal.status,
      'stale_reason', coalesce(v_proposal.stale_reason, 'proposal_not_pending'),
      'conflict_snapshot', v_proposal.conflict_snapshot
    );
  end if;

  v_current := public.capture_route_state(v_proposal.quest_id);
  if v_current is distinct from v_proposal.base_snapshot then
    update public.route_change_proposals set
      status = 'stale',
      stale_reason = 'route_state_changed_after_proposal',
      stale_at = now(),
      resolved_at = now(),
      conflict_snapshot = v_current
    where id = p_proposal_id;
    return jsonb_build_object(
      'fresh', false,
      'status', 'stale',
      'stale_reason', 'route_state_changed_after_proposal',
      'conflict_snapshot', v_current
    );
  end if;
  return jsonb_build_object('fresh', true);
end;
$$;

alter function public.apply_route_change_proposal(uuid, uuid[], uuid)
  rename to apply_route_change_proposal_qst286_base;
alter function public.apply_task_aware_route_change_proposal(uuid, uuid[], uuid)
  rename to apply_task_aware_route_change_proposal_qst286_base;
alter function public.apply_mission_regeneration_proposal(uuid, uuid, uuid)
  rename to apply_mission_regeneration_proposal_qst286_base;

create function public.apply_route_change_proposal(
  p_proposal_id uuid,
  p_accepted_item_ids uuid[],
  p_expected_route_version_id uuid
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_guard jsonb; v_proposal public.route_change_proposals%rowtype;
begin
  v_guard := public.prepare_route_proposal_apply(p_proposal_id);
  if not coalesce((v_guard->>'fresh')::boolean, false) then
    select * into v_proposal from public.route_change_proposals where id=p_proposal_id;
    return jsonb_build_object(
      'proposal_id', p_proposal_id, 'quest_id', v_proposal.quest_id,
      'route_version_id', v_proposal.route_version_id,
      'status', v_guard->>'status',
      'stale_reason', v_guard->>'stale_reason',
      'conflict_snapshot', v_guard->'conflict_snapshot'
    );
  end if;
  return public.apply_route_change_proposal_qst286_base(
    p_proposal_id, p_accepted_item_ids, p_expected_route_version_id
  );
end;
$$;

create function public.apply_task_aware_route_change_proposal(
  p_proposal_id uuid,
  p_accepted_item_ids uuid[],
  p_expected_route_version_id uuid
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_guard jsonb; v_proposal public.route_change_proposals%rowtype;
begin
  v_guard := public.prepare_route_proposal_apply(p_proposal_id);
  if not coalesce((v_guard->>'fresh')::boolean, false) then
    select * into v_proposal from public.route_change_proposals where id=p_proposal_id;
    return jsonb_build_object(
      'proposal_id', p_proposal_id, 'quest_id', v_proposal.quest_id,
      'route_version_id', v_proposal.route_version_id,
      'status', v_guard->>'status',
      'stale_reason', v_guard->>'stale_reason',
      'conflict_snapshot', v_guard->'conflict_snapshot'
    );
  end if;
  return public.apply_task_aware_route_change_proposal_qst286_base(
    p_proposal_id, p_accepted_item_ids, p_expected_route_version_id
  );
end;
$$;

create function public.apply_mission_regeneration_proposal(
  p_proposal_id uuid,
  p_item_id uuid,
  p_expected_route_version_id uuid
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_guard jsonb; v_proposal public.route_change_proposals%rowtype;
begin
  v_guard := public.prepare_route_proposal_apply(p_proposal_id);
  if not coalesce((v_guard->>'fresh')::boolean, false) then
    select * into v_proposal from public.route_change_proposals where id=p_proposal_id;
    return jsonb_build_object(
      'proposal_id', p_proposal_id, 'quest_id', v_proposal.quest_id,
      'route_version_id', v_proposal.route_version_id,
      'status', v_guard->>'status',
      'stale_reason', v_guard->>'stale_reason',
      'conflict_snapshot', v_guard->'conflict_snapshot'
    );
  end if;
  return public.apply_mission_regeneration_proposal_qst286_base(
    p_proposal_id, p_item_id, p_expected_route_version_id
  );
end;
$$;

revoke all on function public.capture_route_state(uuid),
  public.capture_route_proposal_base(),
  public.prepare_route_proposal_apply(uuid),
  public.apply_route_change_proposal_qst286_base(uuid,uuid[],uuid),
  public.apply_task_aware_route_change_proposal_qst286_base(uuid,uuid[],uuid),
  public.apply_mission_regeneration_proposal_qst286_base(uuid,uuid,uuid),
  public.apply_route_change_proposal(uuid,uuid[],uuid),
  public.apply_task_aware_route_change_proposal(uuid,uuid[],uuid),
  public.apply_mission_regeneration_proposal(uuid,uuid,uuid)
from public, anon;

grant execute on function public.apply_route_change_proposal(uuid,uuid[],uuid),
  public.apply_task_aware_route_change_proposal(uuid,uuid[],uuid),
  public.apply_mission_regeneration_proposal(uuid,uuid,uuid)
to authenticated;

commit;
