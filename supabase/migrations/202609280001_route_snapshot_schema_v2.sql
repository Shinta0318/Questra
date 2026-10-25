-- QST-517: keep Flutter and PostgreSQL route freshness snapshots identical.
begin;

create or replace function public.capture_route_state(p_quest_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'snapshotVersion', 2,
    'quest', jsonb_build_object(
      'id', q.id,
      'targetDate', to_char(q.target_date, 'YYYY-MM-DD')
    ),
    'missions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id,
        'status', m.status,
        'progressPercent', m.progress_percent,
        'sortOrder', m.sort_order,
        'isToday', m.is_today,
        'routeState', m.route_state,
        'title', m.title,
        'description', coalesce(m.description, ''),
        'doneCondition', coalesce(m.done_condition, ''),
        'expectedOutput', coalesce(m.expected_output, ''),
        'estimatedDurationDays', m.estimated_duration_days,
        'difficultyScore', m.difficulty_score,
        'sourceRequirement', coalesce(m.source_requirement, 'none'),
        'confidence', coalesce(m.confidence, 0.5)
      ) order by m.id)
      from public.missions m where m.quest_id = q.id
    ), '[]'::jsonb),
    'tasks', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id,
        'missionId', t.mission_id,
        'status', t.status,
        'orderIndex', t.order_index,
        'dependencyIds', coalesce((
          select jsonb_agg(dependency_id order by dependency_id::text)
          from unnest(coalesce(t.dependency_ids, '{}'::uuid[])) dependency_id
        ), '[]'::jsonb),
        'scheduledDate', to_char(t.scheduled_date, 'YYYY-MM-DD'),
        'dueDate', to_char(t.due_date, 'YYYY-MM-DD')
      ) order by t.id)
      from public.tasks t where t.quest_id = q.id
    ), '[]'::jsonb)
  )
  from public.quests q where q.id = p_quest_id;
$$;

-- A v1 proposal cannot prove freshness against the richer v2 contract. Keep it
-- for audit, but require the user to generate a new proposal before applying it.
update public.route_change_proposals p
set
  status = 'stale',
  stale_reason = 'snapshot_schema_version_changed',
  stale_at = now(),
  resolved_at = now(),
  conflict_snapshot = public.capture_route_state(p.quest_id)
where p.status = 'pending'
  and p.base_snapshot->>'snapshotVersion' is distinct from '2';

revoke all on function public.capture_route_state(uuid) from public, anon;

commit;
